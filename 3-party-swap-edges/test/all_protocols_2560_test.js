const { time, expectRevert } = require("@openzeppelin/test-helpers");
const { 
  logEvents, 
  getMostRecentBlockTimestamp,
  logNewSwap, 
  logError, 
  allProtocols, 
  getNewPairing 
} = require('./test_utils')
const Apricot = artifacts.require("Apricot")
const Banana = artifacts.require("Banana")
const Cherry = artifacts.require("Cherry")
const ApricotSwap = artifacts.require("ApricotSwap")
const BananaSwap = artifacts.require("BananaSwap")
const CherrySwap = artifacts.require("CherrySwap")

const DELTA = 500 //TODO: match to ApricotSwap and BananSwap
const SIZE = allProtocols.length/8; // how many cases in this test
const INDEX = 4;// INDEX shows the ith SIZE(512) protocols
const START =INDEX*SIZE;
const END = START+SIZE ;

contract(INDEX+1 + "th"+ SIZE + "Protocols", async (accounts) => {
  it("all", async function() {
    //this call ensures that the contract will not timeout
    this.timeout(0)

    // Deploy all relevant contracts 
    //Apricot
    const apr = await Apricot.deployed()
    const alice_bob_edge = await ApricotSwap.deployed()
    //Banana
    const ban = await Banana.deployed()
    const bob_carol_edge = await BananaSwap.deployed()

    const che = await Cherry.deployed()
    const carol_alice_edge = await CherrySwap.deployed()

    // Since Apricot and Banana both mint 1_000_000 to the first account (which is Alice),
    // we have to send over funds to Bob 
    const alice = accounts[0];
    const bob = accounts[1];
    const carol = accounts[2];

    await apr.transfer(bob, 100_000, { from: alice });
    await ban.transfer(bob, 100_000, { from: alice });
    await che.transfer(bob, 100_000, { from: alice });

    await apr.transfer(carol, 100_000, { from: alice });
    await ban.transfer(carol, 100_000, { from: alice });
    await che.transfer(carol, 100_000, { from: alice });

    //have to allow Apricot Swap to make transfers on alice & bob's behalf
    await apr.increaseAllowance(alice_bob_edge.address, 100_000, { from: alice });
    await apr.increaseAllowance(alice_bob_edge.address, 100_000, { from: bob });
    await apr.increaseAllowance(alice_bob_edge.address, 100_000, { from: carol });

    //have to allow Banana Swap to make transfers on alice & bob's behalf
    await ban.increaseAllowance(bob_carol_edge .address, 100_000, { from: alice });
    await ban.increaseAllowance(bob_carol_edge .address, 100_000, { from: bob });
    await ban.increaseAllowance(bob_carol_edge .address, 100_000, { from: carol });

    //have to allow Banana Swap to make transfers on alice & bob's behalf
    await che.increaseAllowance(carol_alice_edge.address, 100_000, { from: alice });
    await che.increaseAllowance(carol_alice_edge.address, 100_000, { from: bob });
    await che.increaseAllowance(carol_alice_edge.address, 100_000, { from: carol });

  
    ac_path = [alice];
    cb_path = [alice, carol];
    ba_path = [alice, carol, bob];
    

    //Callback for carol to deposit apr escrow premium
    const deposit_escr_prem_apr = async (hashLock, premHashLock, preimage, premPreImage) => {
      await alice_bob_edge.depositEscrowPremium(hashLock, { from: alice });
    };
            
    //Callback for alice to deposit ban escrow premium
    const deposit_escr_prem_ban = async (hashLock, premHashLock, preimage, premPreImage) => {
      await bob_carol_edge.depositEscrowPremium(hashLock, { from: bob });
    };

    //Callback for bob to deposit che escrow premium
    const deposit_escr_prem_che = async (hashLock, premHashLock, preimage, premPreImage) => {
      await carol_alice_edge.depositEscrowPremium(hashLock, { from: carol });
    };

    //Callback for alice to deposit che
    const deposit_red_prem_che = async (hashLock, premHashLock, preimage, premPreImage) => {
      await carol_alice_edge.depositRedemptionPremium(hashLock, premHashLock, premPreImage, ac_path, { from: alice });
    };

    //Callback for bob to deposit apr
    const deposit_red_prem_apr = async (hashLock, premHashLock, preimage, premPreImage) => {
      await alice_bob_edge.depositRedemptionPremium(hashLock, premHashLock, premPreImage, ba_path, { from: bob });
    };

    //Callback for carol to deposit ban
    const deposit_red_prem_ban = async (hashLock, premHashLock, preimage, premPreImage) => {
      await bob_carol_edge.depositRedemptionPremium(hashLock, premHashLock, premPreImage, cb_path, { from: carol });
    };
    
    //Callback for alice to escrow apr
    const escrow_apr = async (hashLock, premHashLock, preimage, premPreImage) => {
      await alice_bob_edge.escrowAsset(hashLock, { from: alice });
    };

    //Callback for bob to escrow ban
    const escrow_ban = async (hashLock, premHashLock, preimage, premPreImage) => {
      await bob_carol_edge.escrowAsset(hashLock, { from: bob });
    };

    //Callback for carol to escrow che
    const escrow_che = async (hashLock, premHashLock, preimage, premPreImage) => {
      await carol_alice_edge.escrowAsset(hashLock, { from:carol });
    };

    //TODO: reverting here
    //Callback for carol to redeem ban
    const redeem_ban = async (hashLock, premHashLock, preimage, premPreImage) => {
      await bob_carol_edge.unlockHashlock(hashLock, preimage, cb_path, { from: carol });
    };

    //Callback for bob to redeem apr
    const redeem_apr = async (hashLock, premHashLock, preimage, premPreImage) => {
      await alice_bob_edge.unlockHashlock(hashLock, preimage, ba_path, { from: bob });
    };
    //Callback for alice to redeem che
    const redeem_che = async (hashLock, premHashLock, preimage, premPreImage) => {
      await carol_alice_edge.unlockHashlock(hashLock, preimage, ac_path, { from: alice });
    };
    
    // settle all assets
    const settle_actions = async (hashLock) => {
      await alice_bob_edge.settleAllAssets(hashLock, { from: alice });
      await bob_carol_edge.settleAllAssets(hashLock, { from: bob });
      await carol_alice_edge.settleAllAssets(hashLock, { from: carol });
   };

    // All possible actions to be taken
    const actions = [
      deposit_escr_prem_apr, //1
      deposit_escr_prem_ban, //2
      deposit_escr_prem_che, //3
      deposit_red_prem_che, //4
      deposit_red_prem_ban, //5
      deposit_red_prem_apr, //6
      escrow_apr, //7
      escrow_ban, //8
      escrow_che, //9
      redeem_che, //10
      redeem_ban, //11
      redeem_apr //12
    ];

    let preimage = "0000000000000000000000000000000000000000000000000000000000000000"
    let actual_preimage
    let hashLock
    let preimage_prem = "0000000000000000000000000000000000000000000000000000000000000001"
    let actual_preimage_prem
    let hashLock_prem
    
    /* tests second 512 of 2^12 different possibilites, given 16 base protocols of length 6, and whether each step was taken in time */
    for (i = START; i < END; i++) {
      //get the preimage and hashLock given the index
      [preimage, actual_preimage, hashLock] = getNewPairing(i, preimage);
      [preimage_prem, actual_preimage_prem, hashLock_prem] = getNewPairing(i, preimage_prem);

      logNewSwap(i, allProtocols[i], actual_preimage, hashLock);

      // for now, start time is most recent block (with some buffer)
      const start_time = (await getMostRecentBlockTimestamp()) + DELTA;
      //Set up Alice-Bob Swap
      let ab_setup = alice_bob_edge.setup(
        100,
        3,
        alice,
        bob,
        apr.address,
        hashLock,
        hashLock_prem,
        start_time,
        ba_path,
        DELTA
      );

      //Set up Bob-Carol Swap
      let bc_setup = bob_carol_edge.setup(
        100, 
        3, 
        bob, 
        carol, 
        ban.address, 
        hashLock,
        hashLock_prem,
        start_time,
        cb_path,
        DELTA
      );

      //Set up Carol-Alice Swap
      let ca_setup = carol_alice_edge.setup(
        100, 
        3, 
        carol, 
        alice, 
        che.address, 
        hashLock,
        hashLock_prem,
        start_time,
        ac_path,
        DELTA
      );

      await Promise.all([ab_setup, bc_setup, ca_setup])
      .then(values => {
        ab_setup = values[0]
        bc_setup = values[1]
        ca_setup = values[2]
      })
      
      const protocol = allProtocols[i]
      // used in switch statement below, which has to check whether previous steps have been taken
      const aprDeposited = protocol[0] == '1';
      const banDeposited = protocol[1] == '1';
      const cheDeposited = protocol[2] == '1';
      const cheRedDeposited = protocol[3] == '1';
      const banRedDeposited = protocol[4] == '1';
      const aprRedDeposited = protocol[5] == '1';
      // const aprEscrowed = protocol[6] == '1';
      // const banEscrowed = protocol[7] == '1';
      // const cheEscrowed = protocol[8] == '1';

      await time.increaseTo(start_time)
      // loop through the steps taken and make refund/redeem call
      for (let j = 0; j < protocol.length; j++) { //length =12
        if (protocol[j] == '1') {
          try {
            switch (j) {
              case 3:
                if (!cheDeposited) {
                  await expectRevert.unspecified(actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem))
                } else {
                  await actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem)
                }
                break
              case 4:
                if (!banDeposited) {
                  await expectRevert.unspecified(actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem))
                } else {
                  await actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem)
                }
                break
              case 5:
                // there are 3 options
                if (!aprDeposited) {
                  await expectRevert.unspecified(actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem))
                } else {
                  await actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem)
                }
                break
              case 6:
                if (!aprRedDeposited || !aprDeposited) {
                  await expectRevert.unspecified(actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem))
                } else {
                  await actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem)
                }
                break
              case 7:
                if (!banRedDeposited || !banDeposited) {
                  await expectRevert.unspecified(actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem))
                } else {
                  await actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem)
                }
                break
              case 8:
                if (!cheRedDeposited || !cheDeposited) {
                  await expectRevert.unspecified(actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem))
                } else {
                  await actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem)
                }
                break
              case 9:
                if (!cheRedDeposited || !cheDeposited) {
                  await expectRevert.unspecified(actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem))
                } else {
                  await actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem)
                }
                break
              case 10:
                if (!banRedDeposited || !banDeposited) {
                  await expectRevert.unspecified(actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem))
                } else {
                  await actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem)
                }
                break
              case 11:
                if (!aprRedDeposited || !aprDeposited ) {
                  await expectRevert.unspecified(actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem))
                } else {
                  await actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem)
                }
                break
              default:
                await actions[j](hashLock, hashLock_prem, actual_preimage, actual_preimage_prem)
                break
            }
          } catch (e) {
            logError(i, j + 1, allProtocols[i], actual_preimage, hashLock, e)
          }
        }
      }
       await time.increaseTo(start_time + DELTA * 13)
       await settle_actions(hashLock)
      // get past events
      const aprStartBlock = ab_setup.logs[0].blockNumber
      const banStartBlock = bc_setup.logs[0].blockNumber
      const cheStartBlock = ca_setup.logs[0].blockNumber

      let apr_events = alice_bob_edge.getPastEvents("allEvents", {
        fromBlock: aprStartBlock,
        toBlock:  "latest"}
      )
      let ban_events = bob_carol_edge .getPastEvents("allEvents", {
        fromBlock: banStartBlock,
        toBlock:  "latest"}
      )
      let che_events = carol_alice_edge.getPastEvents("allEvents", {
        fromBlock: cheStartBlock,
        toBlock:  "latest"}
      )
      await Promise.all([apr_events, ban_events, che_events])
      .then(values => {
        apr_events = values[0]
        ban_events = values[1]
        che_events = values[2]
      })
      //log
      logEvents(i, apr_events, ban_events, che_events)
    }
  });
});
