const { time, expectRevert } = require("@openzeppelin/test-helpers");
const {
  logEvents,
  getMostRecentBlockTimestamp,
  logNewSwap,
  logError,
  allProtocols,
  getNewPairing,
} = require("./test_utils");

/* the Solidity contracts */
const Apricot = artifacts.require("Apricot");
const ApricotSwap = artifacts.require("TwoPartySwapApricot");
const Banana = artifacts.require("Banana");
const BananaSwap = artifacts.require("TwoPartySwapBanana");

const DELTA = 500 //TODO: match to ApricotSwap and BananSwap
const SIZE = allProtocols.length/2; // how many cases in this test
const INDEX = 0;// INDEX shows the ith SIZE(512) protocols
const START =INDEX*SIZE;
const END = START+SIZE;

contract(INDEX+1 + "th"+ SIZE + "Protocols", async (accounts) => {
  it("all", async function() {
    //this call ensures that the contract will not timeout
    this.timeout(0);

    // Deploy all relevant contracts
    const apr = await Apricot.deployed();
    const apr_swap = await ApricotSwap.deployed();
    const ban = await Banana.deployed();
    const ban_swap = await BananaSwap.deployed();

    // Since Apricot and Banana both mint 1_000_000 to the first account (which is Alice),
    // we have to send over funds to Bob
    const alice = accounts[0];
    const bob = accounts[1];
    await apr.transfer(bob, 500_000, { from: alice });
    await ban.transfer(bob, 500_000, { from: alice });

    //have to allow Apricot Swap to make transfers on alice & bob's behalf
    await apr.increaseAllowance(apr_swap.address, 10_000, { from: alice });
    await apr.increaseAllowance(apr_swap.address, 10_000, { from: bob });

    //have to allow Banana Swap to make transfers on alice & bob's behalf
    await ban.increaseAllowance(ban_swap.address, 10_000, { from: alice });
    await ban.increaseAllowance(ban_swap.address, 10_000, { from: bob });

    //Callback for alice to deposit ban
    const deposit_ban = async (hashLock, preimage) => {
      await ban_swap.depositPremium(hashLock, { from: alice });
    };

    //Callback for bob to deposit apr
    const deposit_apr = async (hashLock, preimage) => {
      await apr_swap.depositPremium(hashLock, { from: bob });
    };

    //Callback for alice to escrow apr
    const escrow_apr = async (hashLock, preimage) => {
      await apr_swap.escrowAsset(hashLock, { from: alice });
    };

    //Callback for bob to deposit ban
    const escrow_ban = async (hashLock, preimage) => {
      await ban_swap.escrowAsset(hashLock, { from: bob });
    };

    //Callback for alice to redeem ban
    const redeem_ban = async (hashLock, preimage) => {
      await ban_swap.redeemAsset(preimage, hashLock, { from: alice });
      //alice reffund premium
    };

    //Callback for bob to redeem apr
    const redeem_apr = async (hashLock, preimage) => {
      await apr_swap.redeemAsset(preimage, hashLock, { from: bob });
    };

    //Callback for alice to refund apr and redeem premium
    const settle_actions = async (hashLock) => {
       await apr_swap.settleAllAssets(hashLock, { from: alice });
      await ban_swap.settleAllAssets(hashLock, { from: alice });
    };

    // All possible actions to be taken
    const actions = [
      deposit_ban, // 0
      deposit_apr, // 1
      escrow_apr, // 2
      escrow_ban, // 3
      redeem_ban, // 4
      redeem_apr // 5
    ];

    let preimage =
      "0000000000000000000000000000000000000000000000000000000000000000";
    let actual_preimage;
    let hashLock;

    /* tests first 512 of 1024 different possibilites, given 16 base protocols of length 6, and whether each step was taken in time */
    for (let i = START ; i < END; i++) {
      //get the preimage and hashLock given the index
      [preimage, actual_preimage, hashLock] = getNewPairing(i, preimage);
      // log this swap
      logNewSwap(i, allProtocols[i], actual_preimage, hashLock);

      // for now, start time is most recent block (with some buffer)
      const start_time = (await getMostRecentBlockTimestamp()) + DELTA;

      //Set up Apr Swap
      let apr_setup = apr_swap.setup(
        100,
        1,
        alice,
        bob,
        apr.address,
        hashLock,
        start_time,
        DELTA
      );

      //Set up Banana Swap
      let ban_setup = ban_swap.setup(
        100, 
        2, 
        alice, 
        bob, 
        ban.address, 
        hashLock,
        start_time,
        DELTA
      );

      await Promise.all([apr_setup, ban_setup]).then((values) => {
        apr_setup = values[0];
        ban_setup = values[1];
      });

      const protocol = allProtocols[i];
      // used in switch statement below, which has to check whether previous steps have been taken
      const banDeposited = protocol[0] == "1" && protocol[1] == "1";
      const aprDeposited = protocol[2] == "1" && protocol[3] == "1";
      const aprEscrowed = protocol[4] == "1" && protocol[5] == "1";
      const banEscrowed = protocol[6] == "1" && protocol[7] == "1";

      await time.increaseTo(start_time);
      // loop through the steps taken and make refund/redeem call
      for (let j = 0; j < protocol.length; j += 2) {
        const currentStep = j / 2;
        // only perform an action if you're supposed to
        if (protocol[j] == "1") {
          try {
            if (protocol[j + 1] == '0') { // missed the call 
              const duration = (currentStep + 1) * DELTA + 1
              await time.increaseTo(start_time + duration)
              await expectRevert.unspecified(actions[currentStep](hashLock, actual_preimage))
            } else { // made the call in time
              switch (currentStep) {
                case 2:
                  if (!aprDeposited) {
                    await expectRevert.unspecified(actions[currentStep](hashLock, actual_preimage))
                  } else {
                    await actions[currentStep](hashLock, actual_preimage)
                  }
                  break;
                case 3:
                  if (!banDeposited) {
                    await expectRevert.unspecified(actions[currentStep](hashLock, actual_preimage))
                  } else {
                    await actions[currentStep](hashLock, actual_preimage)
                  }
                  break;
                case 4:
                  // there are 3 options
                  if (!banDeposited || !banEscrowed) {
                    await expectRevert.unspecified(actions[currentStep](hashLock, actual_preimage))
                  } else {
                    await actions[currentStep](hashLock, actual_preimage)
                  }
                  break;
                case 5:
                  if (!aprDeposited || !aprEscrowed) {
                    await expectRevert.unspecified(actions[currentStep](hashLock, actual_preimage))
                  } else {
                    await actions[currentStep](hashLock, actual_preimage)
                  }
                  break;
                default:
                  await actions[currentStep](hashLock, actual_preimage)
                  break
              }
            }
          } catch (e) {
            logError(i, j, currentStep, allProtocols[i], actual_preimage, hashLock, e)
          }
        }
      }
      // settle all assets on both contracts
      await time.increaseTo(start_time + 7 * DELTA)
      await settle_actions(hashLock)
      // get past events
      const aprStartBlock = apr_setup.logs[0].blockNumber;
      const banStartBlock = ban_setup.logs[0].blockNumber;
      let apr_events = apr_swap.getPastEvents("allEvents", {
        fromBlock: aprStartBlock,
        toBlock: "latest",
      });
      let ban_events = ban_swap.getPastEvents("allEvents", {
        fromBlock: banStartBlock,
        toBlock:  "latest"}
      )
      await Promise.all([apr_events, ban_events])
      .then(values => {
        apr_events = values[0]
        ban_events = values[1]
      })
      //log
      logEvents(i, apr_events, ban_events);
    }
  });
});
