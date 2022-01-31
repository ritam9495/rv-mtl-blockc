const { time, expectRevert } = require("@openzeppelin/test-helpers");
const { 
  logEvents, 
  getMostRecentBlockTimestamp,
  logNewAuction, 
  logError, 
  getNewPairing,
  allProtocols
} = require('./test_utils')

const Coin = artifacts.require("Coin")
const CoinAuction = artifacts.require("CoinAuction")
const Ticket = artifacts.require("Ticket")
const TicketAuction = artifacts.require("TicketAuction")

const DELTA = 5000 //TODO: match to ApricotSwap and BananaSwap
const START = 2500
const END = START+500
contract("[Auction],start from "+START+" to "+ END, async (accounts) => {
  it("all", async function() {
    //this call ensures that the contract will not timeout
    this.timeout(0)

    // Deploy all relevant contracts 
    const coin = await Coin.deployed()
    const coinAuction = await CoinAuction.deployed()
    const ticket = await Ticket.deployed()
    const ticketAuction = await TicketAuction.deployed()

    const alice = accounts[0];
    const bob = accounts[1];
    const carol = accounts[2];

    //transfer coins over to bob and carol, since alice gets all 1_000_000 of minted token.
    await coin.transfer(bob, 300_000, { from: alice });
    await coin.transfer(carol, 300_000, { from: alice });

    //have to allow CoinAuction to make transfers on everyone's behalf
    await coin.increaseAllowance(coinAuction.address, 100_000, { from: alice });
    await coin.increaseAllowance(coinAuction.address, 100_000, { from: bob });
    await coin.increaseAllowance(coinAuction.address, 100_000, { from: carol });

    //have to allow TicketAuction to make transfers on everyone's behalf
    await ticket.increaseAllowance(ticketAuction.address, 100_000, { from: alice });
    await ticket.increaseAllowance(ticketAuction.address, 100_000, { from: bob });
    await ticket.increaseAllowance(ticketAuction.address, 100_000, { from: carol });

    // possible paths
    const a_path = [alice];
    const ab_path = [alice, bob];
    const ac_path = [alice, carol];
    const acb_path = [alice, carol, bob];
    const abc_path = [alice, bob, carol];

    const bid_amount = 100

    // ALL PHASES

    const do_nothing = async (auctionID, secretB, secretC) => {
      // Dummy function to make indexing easier
      return true
    }

    //--------------------------------COIN----------------------------------

    // [COIN] BIDDING

    const bob_bids = async (auctionID, secretB, secretC) => {
      await coinAuction.bid(auctionID,  bid_amount, {from: bob})
    }

    const both_bid = async (auctionID, secretB, secretC) => {
      await coinAuction.bid(auctionID,  bid_amount + 1, {from: bob})
      await coinAuction.bid(auctionID, bid_amount, {from: carol})
    }

    // [COIN] SB REVEALER

    const declare_bob_coin = async (auctionID, secretB, secretC) => {
      await coinAuction.declare(auctionID, secretB, a_path, a_path, {from: alice})
    }

    const bob_challenge_coin_sb_1 = async (auctionID, secretB, secretC) => {
      await coinAuction.challenge(auctionID, secretB, ab_path, ab_path, {from: bob})
    }

    const bob_challenge_coin_sb_2 = async (auctionID, secretB, secretC) => {
      await coinAuction.challenge(auctionID, secretB, acb_path, acb_path, {from: bob})
    }

    const carol_challenge_coin_sb_1 = async (auctionID, secretB, secretC) => {
      await coinAuction.challenge(auctionID, secretB, ac_path, ac_path, {from: carol})
    }

    const carol_challenge_coin_sb_2 = async (auctionID, secretB, secretC) => {
      await coinAuction.challenge(auctionID, secretB, abc_path, abc_path, {from: carol})
    }

    // [COIN] SC REVEALER

    const declare_carol_coin = async (auctionID, secretB, secretC) => {
      await coinAuction.declare(auctionID, secretC, a_path, a_path, {from: alice})
    }

    const bob_challenge_coin_sc_1 = async (auctionID, secretB, secretC) => {
      await coinAuction.challenge(auctionID, secretC, ab_path, ab_path, {from: bob})
    }

    const bob_challenge_coin_sc_2 = async (auctionID, secretB, secretC) => {
      await coinAuction.challenge(auctionID, secretC, acb_path, acb_path, {from: bob})
    }
    
    const carol_challenge_coin_sc_1 = async (auctionID, secretB, secretC) => {
      await coinAuction.challenge(auctionID, secretC, ac_path, ac_path, {from: carol})
    }

    const carol_challenge_coin_sc_2 = async (auctionID, secretB, secretC) => {
      await coinAuction.challenge(auctionID, secretC, abc_path, abc_path, {from: carol})
    }

    //--------------------------------TICKET--------------------------------
    
    // [TICKET] SB REVEALER

    const declare_bob_ticket = async (auctionID, secretB, secretC) => {
      await ticketAuction.declare(auctionID, secretB, a_path, a_path, {from: alice})
    }

    const bob_challenge_ticket_sb_1 = async (auctionID, secretB, secretC) => {
      await ticketAuction.challenge(auctionID, secretB, ab_path, ab_path, {from: bob})
    }

    const bob_challenge_ticket_sb_2 = async (auctionID, secretB, secretC) => {
      await ticketAuction.challenge(auctionID, secretB, acb_path, acb_path, {from: bob})
    }

    const carol_challenge_ticket_sb_1 = async (auctionID, secretB, secretC) => {
      await ticketAuction.challenge(auctionID, secretB, ac_path, ac_path, {from: carol})
    }

    const carol_challenge_ticket_sb_2 = async (auctionID, secretB, secretC) => {
      await ticketAuction.challenge(auctionID, secretB, abc_path, abc_path, {from: carol})
    }

    // [TICKET] SC REVEALER

    const declare_carol_ticket = async (auctionID, secretB, secretC) => {
      await ticketAuction.declare(auctionID, secretC, a_path, a_path, {from: alice})
    }

    const bob_challenge_ticket_sc_1 = async (auctionID, secretB, secretC) => {
      await ticketAuction.challenge(auctionID, secretC, ab_path, ab_path, {from: bob})
    }

    const bob_challenge_ticket_sc_2 = async (auctionID, secretB, secretC) => {
      await ticketAuction.challenge(auctionID, secretC, acb_path, acb_path, {from: bob})
    }

    const carol_challenge_ticket_sc_1 = async (auctionID, secretB, secretC) => {
      await ticketAuction.challenge(auctionID, secretC, ac_path, ac_path, {from: carol})
    }

    const carol_challenge_ticket_sc_2 = async (auctionID, secretB, secretC) => {
      await ticketAuction.challenge(auctionID, secretC, abc_path, abc_path, {from: carol})
    }

    // All possible actions to be taken. These have one-to-one mapping with 
    // the actions taken in the README
    const actions = [
      // 0 BIDDING [COIN] 
      [do_nothing, bob_bids, both_bid], 
      // 1 SB REVEALER [COIN] 
      [do_nothing, declare_bob_coin, bob_challenge_coin_sb_1, bob_challenge_coin_sb_2,
      carol_challenge_coin_sb_1, carol_challenge_coin_sb_2],
      // 2 SC REVEALER [COIN]
      [do_nothing, declare_carol_coin, bob_challenge_coin_sc_1, bob_challenge_coin_sc_2,
      carol_challenge_coin_sc_1, carol_challenge_coin_sc_2], 
      // 3 SB REVEALER [TICKET] 
      [do_nothing, declare_bob_ticket, bob_challenge_ticket_sb_1, bob_challenge_ticket_sb_2,
      carol_challenge_ticket_sb_1, carol_challenge_ticket_sb_2], 
      // 4 SC REVEALER [TICKET]
      [do_nothing, declare_carol_ticket, bob_challenge_ticket_sc_1, bob_challenge_ticket_sc_2,
      carol_challenge_ticket_sc_1, carol_challenge_ticket_sc_2],
    ];

    // auctionID (preimage not actually used as paramter, but guarantees some 
    // privacy for Bob and Carol's auction)
    let preimage = "0x0000000000000000000000000000000000000000000000000000000000000000"
    let auctionID

    // Alice uses hashB to declare Bob the winner
    let secretB = "0x0000000000000000000000000000000000000000000000000000000000000001"
    let hashB

    // Alice uses hashC to declare Carol the winner, both Bob and Carol use secretC to challenge
    // (since Carol is the loser in all cases)
    let secretC = "0x0000000000000000000000000000000000000000000000000000000000000010"
    let hashC
    
    /* tests 500 iterations, starting at START*/
    for (let i = START; i < END; i++) {
      // get new hashes
      [preimage, auctionID] = getNewPairing(i, preimage);
      [secretB, hashB] = getNewPairing(i, secretB);
      [secretC, hashC] = getNewPairing(i, secretC);

      logNewAuction(i, allProtocols[i], preimage, auctionID, secretB, hashB, secretC, hashC);

      // for now, start time is most recent block (with some buffer)
      const start_time = (await getMostRecentBlockTimestamp()) + DELTA

      //Set up Coin Auction
      const ca_setup = await coinAuction.setup(
        auctionID,
        2,
        [bob, carol],
        [hashB, hashC],
        coin.address,
        start_time,
        {from: alice}
      );

      //Set up Ticket Auction
      const ta_setup = await ticketAuction.setup(
        auctionID,
        100,
        [bob, carol],
        [hashB, hashC],
        ticket.address,
        start_time,
        {from: alice}
      );
      
      // this iteration's protocol
      const protocol = allProtocols[i]

      // used in switch statement below, which has to check whether previous steps have been taken
      
      // ------------------------------------------COIN------------------------------------------------
      const bob_bid = protocol[0] > 0
      const carol_bid = protocol[0] == 2

      const bob_challenging_without_bidding_1 = !bob_bid && (protocol[1] == 2 || protocol[1] == 3)
      const carol_challenging_without_bidding_1 = !carol_bid && (protocol[1] == 4 || protocol[1] == 5)
      
      const bob_challenging_without_bidding_2 = !bob_bid && (protocol[2] == 2 || protocol[2] == 3)
      const carol_challenging_without_bidding_2 = !carol_bid && (protocol[2] == 4 || protocol[2] == 5)

      // Used in declaration_after_challenge_coin just below
      const carol_challenge_1 = carol_bid && (protocol[1] == 4 || protocol[1] == 5)
      const bob_challenge_1 = bob_bid & (protocol[1] == 2 || protocol[1] == 3)

      const declaration_after_challenge_coin = (protocol[2] == 1 && (bob_challenge_1 || carol_challenge_1 || protocol[1] == 1))
      // don't have to worry about Bob or Carol succesfully 

      // ------------------------------------------TICKET------------------------------------------------
      const declaration_after_challenge_ticket = (protocol[4] == 1 && protocol[3] > 0)

      // go to start time
      await time.increaseTo(start_time)

      // Avoids repetitive syntax in switch statement
      const do_action = async (i) => {
        return actions[i][protocol[i]](auctionID, secretB, secretC)
      }

      // Execute protocol. Ex: [0, 3, 2, 4, 4]
      for (let j = 0; j < protocol.length; j++) { // length = 5
        // If protocol[j] == 0, the party does nothing. So, we can just skip.
        if (protocol[j] > 0) {
          try {
            switch (j) {
              // Bidding always occurs
              case 0:
                await do_action(j)
                break
              // Can't challenge on the coin chain without bidding, or declare after challenge
              case 1:
                if (bob_challenging_without_bidding_1 || carol_challenging_without_bidding_1) {
                  await expectRevert.unspecified(do_action(j))
                } else {
                  await do_action(j)
                }
                break
              case 2:
                if (bob_challenging_without_bidding_2 || carol_challenging_without_bidding_2) {
                  await expectRevert.unspecified(do_action(j))
                } else if (declaration_after_challenge_coin) {
                  await expectRevert.unspecified(do_action(j))
                } else {
                  await do_action(j)
                }
                break
              case 3:
                await do_action(j)
                break
              // Can't declare after a challenge
              case 4:
                if (declaration_after_challenge_ticket) {
                  await expectRevert.unspecified(do_action(j))
                } else {
                  await do_action(j)
                  break
                }
            }
          } catch (e) {
            // outputs to logs/stderr.txt
            logError(i, j, allProtocols[i], preimage, auctionID, e)
          }
        }
      }

      // go beyond challenge phase of auction and settle all assets
      await time.increaseTo(start_time + 10 * DELTA)
      await coinAuction.settle(auctionID, {from: alice})
      await ticketAuction.settle(auctionID, {from: alice})

      // get past events
      const caStartBlock = ca_setup.logs[0].blockNumber
      const taStartBlock = ta_setup.logs[0].blockNumber

      const caEvents = await coinAuction.getPastEvents("allEvents", {
        fromBlock: caStartBlock,
        toBlock:  "latest"}
      )
      
      const taEvents = await ticketAuction.getPastEvents("allEvents", {
        fromBlock: taStartBlock,
        toBlock:  "latest"}
      )
      // log the events
      logEvents(i, caEvents, taEvents)
    }
  });
});
