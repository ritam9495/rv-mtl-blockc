const { assert } = require("chai");
const chai = require("chai");
// Enable and inject BN dependency
chai.use(require("chai-bignumber")());
const sha256 = require("crypto-js/sha256");

// get the Console class
const { Console } = require("console");
// get fs module for creating write streams
const fs = require("fs");
const { start } = require("repl");

// make a new logger so that we can output to a text file.
const Logger = new Console({
  stdout: fs.createWriteStream("./logs/log_1.txt"),
  stderr: fs.createWriteStream("./logs/std_err.txt"),
});

const Apricot = artifacts.require("Apricot");
const ApricotSwap = artifacts.require("TwoPartySwapApricot");
const Banana = artifacts.require("Banana");
const BananaSwap = artifacts.require("TwoPartySwapBanana");

/**
 * This function formats Contract events, using the
 * initial_block_time to conver the timestamp proeperty
 */
const formatEvents = (initial_block_time, events) => {
  const formatted_events = [];
  // loop over all events
  for (const apr_event of events) {
    const formatted_event = {};
    formatted_event.event = apr_event.event;
    const props = apr_event.returnValues;
    const formatted_props = {};
    for (const key in props) {
      //TODO: check whether it's a number instead
      if (key.toString().length > 1) {
        if (key.toString() === "timestamp") {
          //TODO: make sure that converting from BigNumbers doesn't cause an issue
          formatted_props[key] =
            props[key].valueOf() - initial_block_time.valueOf();
        } else {
          formatted_props[key] = props[key];
        }
      }
    }
    formatted_event.props = formatted_props;
    // use Number.isInteger()
    formatted_events.push(formatted_event);
  }
  return formatted_events;
};

contract("Simple Swap", async (accounts) => {
  /*
    This test checks that one side of the swap goes through without error
  */
  it("One Side", async () => {
    // Deploy contracts
    const apr = await Apricot.deployed();
    const swap = await ApricotSwap.deployed();

    //alice has to transfer some ammount to Bob at start because she was minted all of the coins.
    const alice = accounts[0];
    const bob = accounts[1];
    await apr.transfer(bob, 100, { from: alice });

    //create a hashlock for the contract
    // Used: https://emn178.github.io/online-tools/sha256.html
    // 'secret' --> 0x736563726574
    const preimage =
      "0x7365637265740000000000000000000000000000000000000000000000000000";
    hashLock =
      "0x497a39b618484855ebb5a2cabf6ee52ff092e7c17f8bfe79313529f9774f83a2";

    //have to allow swap to make transfers on alice & bob's behalf
    await apr.increaseAllowance(swap.address, 10_000, { from: alice });
    await apr.increaseAllowance(swap.address, 10_000, { from: bob });

    //Alice sets up the swap
    await swap.setup(1_000, 10, alice, bob, apr.address, hashLock);

    //Bob deposits premium
    await swap.depositPremium(hashLock, { from: bob });

    //Alice escrows token
    await swap.escrowAsset(hashLock, { from: alice });

    //Bob redeems asset
    await swap.redeemAsset(preimage, hashLock, { from: bob });
  });

  /*
    This test checks that both sides 
  */
  it("Both Sides", async () => {
    //Apricot
    const apr = await Apricot.deployed();
    const apr_swap = await ApricotSwap.deployed();
    //Banana
    const ban = await Banana.deployed();
    const ban_swap = await BananaSwap.deployed();

    //alice has to transfer some ammount to Bob at start because she was minted all of the coins.
    const alice = accounts[0];
    const bob = accounts[1];

    await apr.transfer(bob, 100, { from: alice });
    await ban.transfer(bob, 10_000, { from: alice });

    //create a hashlock for the contract
    // Used: https://emn178.github.io/online-tools/sha256.html
    // Incremented preimage from test 1 above
    const preimage =
      "0x8365637265740000000000000000000000000000000000000000000000000000";
    const hashLock =
      "0x964147060975cf2059ef324ae1321762831fb1cc3f7008f932ff2fda73680475";

    //have to allow Apricot Swap to make transfers on alice & bob's behalf
    await apr.increaseAllowance(apr_swap.address, 10_000, { from: alice });
    await apr.increaseAllowance(apr_swap.address, 10_000, { from: bob });

    //have to allow Banana Swap to make transfers on alice & bob's behalf
    await ban.increaseAllowance(ban_swap.address, 10_000, { from: alice });
    await ban.increaseAllowance(ban_swap.address, 10_000, { from: bob });

    //get most recent block time, and use that as start_time
    const blockNum = await web3.eth.getBlockNumber()
    const block = await web3.eth.getBlock(blockNum)
    const start_time = block['timestamp']

    //Set up Apr Swap
    const setUp = await apr_swap.setup(
      1_000,
      10,
      alice,
      bob,
      apr.address,
      hashLock,
      start_time
    );

    //get initial block number
    const initial_block = setUp.logs[0].blockNumber;

    //Set up Banana Swap
    await ban_swap.setup(1_000, 10, alice, bob, ban.address, hashLock);

    // Step 1: Alice deposits premium on Banana chain
    await ban_swap.depositPremium(hashLock, { from: alice });

    //Step 2: Bob deposits premium on Apricot chain
    await apr_swap.depositPremium(hashLock, { from: bob });

    //Step 3: Alice escrows asset on Apricot chain
    await apr_swap.escrowAsset(hashLock, { from: alice });

    //Step 4: Bob escrows asset on Banana chain
    await ban_swap.escrowAsset(hashLock, { from: bob });

    //Step 5: Alice redeems Bananas
    await ban_swap.redeemAsset(preimage, hashLock, { from: alice });

    //Step 6: Bob redeems Apricots
    await apr_swap.redeemAsset(preimage, hashLock, { from: bob });

    // get all past events from initial block (taken from apr_swap.setup())
    const apr_events = await apr_swap.getPastEvents("allEvents", {
      fromBlock: initial_block,
      toBlock: "latest",
    });
    const ban_events = await ban_swap.getPastEvents("allEvents", {
      fromBlock: initial_block,
      toBlock: "latest",
    });

    // log all events using initial block time
    const initial_block_time = apr_events[0].returnValues.timestamp;
    Logger.log("Apricot:");
    Logger.log(formatEvents(initial_block_time, apr_events));
    Logger.log("Banana:");
    Logger.log(formatEvents(initial_block_time, ban_events));
    // Logger.log(apr_events)
  });
});
