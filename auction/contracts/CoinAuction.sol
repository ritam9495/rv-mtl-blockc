  // SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./libraries/token/ERC20/ERC20.sol";

contract CoinAuction {

  // We will manipulate the DELTA variable (seconds) to see how sucessful the monitor is
    uint constant DELTA = 5000; //TODO: choose your DELTA (in milliseconds)

    // an Auction
    struct Auction {
      address auctioneer;
      HashKey[] hashKeys;
      uint expectedpremium;
      address assetName;
      uint maxBid;
      address winner;
      uint startTime;
      bool settled;
      uint currentpremium;
      uint currentbids;
      bytes32 auctionID;
    }

    // the hashKey triple, as defied in the paper.
    struct HashKey {
      bytes32 secret;
      address[] path;
      bytes32[] signatures;
    }

    // various deadlines for phases of the protocol
    struct Deadlines {
      uint bid;
      uint declaration;
      uint challenge;
    }

    // Mappings that store information for our contract
    mapping(bytes32 => Auction) auctions;
    mapping(bytes32 => address[]) bidders;
    mapping(bytes32 => mapping(address => uint)) bids;
    mapping(bytes32 => Deadlines) deadlines;
    mapping(bytes32 => mapping(bytes32 => address)) hashLocks;

    event SetUp(
      uint timeStamp,
      bytes32 auctionID,
      address auctioneer,
      address assetName,
      uint expectedPremium,
      address[] participants,
      bytes32[] hashLocks,
      uint delta,
      uint startTime
    );

    event Bid(
      uint timeStamp,
      bytes32 auctionID,
      address messageSender,
      uint amount,
      address transferFrom,
      address transferTo
    );

    event Declaration(
      uint timeStamp,
      bytes32 auctionID,
      address messageSender,
      bytes32 secret,
      address[] path
    );

    event Challenge(
      uint timeStamp,
      bytes32 auctionID,   
      address messageSender,
      bytes32 secret,
      address[] path
    );
    event DepositPremium(
      uint timestamp,
      bytes32 auctionID,
      address messageSender,
      uint amount,
      address transferFrom,
      address transferTo,
      uint currentpremium
    );
    event RedeemPremium(
      uint timestamp,
      bytes32 auctionID,
      address messageSender,
      uint amount,
      address transferFrom,
      address transferTo,
      uint currentpremium
    );
    event RefundPremium(
      uint timestamp,
      bytes32 auctionID,
      address messageSender,
      uint amount,
      address transferFrom,
      address transferTo,
       uint currentpremium
    );
    event RefundBids(
      uint timestamp,
      bytes32 auctionID,
      address messageSender,
      uint amount,
      address transferFrom,
      address transferTo,
      uint currentbids
    );
    event RedeemBids(
      uint timestamp,
      bytes32 auctionID,
      address messageSender,
      uint amount,
      address transferFrom,
      address transferTo,
      uint currentbids
    );

    event Settlement(
      uint timeStamp,
      bytes32 auctionID,
      address messageSender,
      uint hashKeysLength,
      uint currentbids,
      uint currentpremium
    );

    modifier canSetup(
      bytes32 auctionID, 
      uint participantsLength, 
      uint hashLocksLength, 
      address assetName, 
      uint premium) {
      require(ERC20(assetName).balanceOf(msg.sender) >= premium, "[canSetup] balance not enough for premium");
      require(auctions[auctionID].auctioneer == address(0), "[canSetup]: auctions[auctionID].auctioneer != address(0)");
      require(hashLocksLength == participantsLength, "[canSetup]: participantsLength != hashLocksLength");
      _;
    }

    modifier canBid(bytes32 auctionID, uint amount) {
      require(amount>0, "[canBid] cannot bid no more than 0");
      require(block.timestamp <= deadlines[auctionID].bid, "[canBid] missed bidding period");
      bool isBidder = false;
      for (uint i = 0; i < bidders[auctionID].length; i++) {
        if (bidders[auctionID][i] == msg.sender) {
          isBidder = true;
          require(ERC20(auctions[auctionID].assetName).balanceOf(msg.sender) >= amount, "[canBid] balance not enough");
          require(bids[auctionID][msg.sender] == 0, "[canBid] bids[auctionID][msg.sender] != 0");
          break;
        }
      }
      require(isBidder, "[canBid]: !isBidder");
      _;
    }

    modifier canDeclare(
      bytes32 auctionID,
      bytes32 secret,
      address[] memory path, 
      bytes32[] memory signatures) {
      require(block.timestamp <= deadlines[auctionID].declaration, "[canDeclare] did not complete action in time");
      require(auctions[auctionID].hashKeys.length == 0, "[canDeclare] auctions[auctionID].hashKeys.length != 0");
      require(msg.sender == auctions[auctionID].auctioneer, "[canDeclare] msg.sender is not auctioneer");
      require(path.length == 1 && signatures.length == 1, "[canDeclare] array lengths != 1");
      require(hashLocks[auctionID][sha256(abi.encode(secret))] != address(0), "[canDeclare]: not a valid secret");
      _;
    }

    modifier canChallenge(
      bytes32 auctionID,
      bytes32 secret,
      address[] memory path, 
      bytes32[] memory signatures) {
      require(block.timestamp <= auctions[auctionID].startTime + DELTA * (path.length + 1), "[canChallenge] did not complete challenge in time");
      require(bids[auctionID][msg.sender] != 0, "[canChallenge] challenger did not submit bid");
      require(hashLocks[auctionID][sha256(abi.encode(secret))] != address(0), "[canChallenge]: not a valid secret");
      // make sure that your challenge is made in time (dependent on the path/signature length)
      require(path.length == signatures.length, "path.length != signatures.length");
      bool secretAlreadyExists = false;
      for (uint i = 0; i < auctions[auctionID].hashKeys.length; i++) {
        if (auctions[auctionID].hashKeys[i].secret == secret) {
          secretAlreadyExists = true;
        }
      }
      require(!secretAlreadyExists, "[canChallenge] secretAlreadyExists");
      _;
    }

    modifier canRedeemBids(
      bytes32 auctionID, 
      address winner,
      uint amount){
      require(block.timestamp >= deadlines[auctionID].challenge, "[canRedeemBids] did not wait challenge to wait");
      require(auctions[auctionID].hashKeys.length == 1, "[canRedeemBids] auctions[auctionID].hashKeys.length != 1");
      require(auctions[auctionID].winner == winner, "[canRedeemBids]: not the winner");
      require(auctions[auctionID].maxBid == amount, "[canRedeemBids]: not the correct amount");
      require(auctions[auctionID].currentbids >= amount,"[canRedeemBids]: not enough balance");
      _;
    }
  modifier canRefundBids(
      bytes32 auctionID, 
      address participant,
      uint amount){
      require(block.timestamp >= deadlines[auctionID].challenge, "[canRefundBids] did not wait challenge to wait");
      require(bids[auctionID][participant] != 0, "[canRefundBids]: does not bid at all");
      require(bids[auctionID][participant] == amount, "[canRefundBids]: not the correct amount");
      require(auctions[auctionID].currentbids >= amount,"[canRefundBids]: not enough balance");
      _;
    }

    modifier canRefundPremium(
      bytes32 auctionID, 
      address participant,
      uint amount){
      require(block.timestamp >= deadlines[auctionID].challenge, "[canRefundPremium] did not wait challenge to wait");
      require(auctions[auctionID].auctioneer == participant, "[canRefundPremium]: the recipent is not auctioneer");
      require(auctions[auctionID].expectedpremium == amount, "[canRefundPremium]: not the correct amount");
      require(auctions[auctionID].currentpremium >= amount,"[canRefundPremium]: not enough balance");
      
      _;
    }
      modifier canRedeemPremium(
      bytes32 auctionID, 
      address participant,
      uint amount){
      require(block.timestamp >= deadlines[auctionID].challenge, "[canRefundPremium] did not wait challenge to wait");
      require(auctions[auctionID].currentpremium >= amount,"[canRefundPremium]: not enough balance");
      _;
    }
    

    modifier canSettle(bytes32 auctionID) {
      require(!auctions[auctionID].settled, "[canSettle] auction was already settled");
      require(block.timestamp >= deadlines[auctionID].challenge, "[canSettle] tried to settle before challenge phase");
      require(bids[auctionID][msg.sender] != 0 || auctions[auctionID].auctioneer == msg.sender, "[canSettle] either not auctioneer or didn't bid");
      _;
    }

    // Auctioneer will call this to set up the auction. 
    function setup(
      bytes32 auctionID, 
      uint premium, 
      address[] memory participants,
      bytes32[] memory locks,
      address assetName,
      uint startTime) 
      public canSetup(auctionID, participants.length, locks.length, assetName, premium) {
      
      // setting up auction variables 
      auctions[auctionID].auctioneer = msg.sender;
      auctions[auctionID].assetName = assetName;
      auctions[auctionID].startTime = startTime;
      auctions[auctionID].expectedpremium = premium;
      auctions[auctionID].currentbids = 0;
      auctions[auctionID].currentpremium = 0;
      auctions[auctionID].auctionID = auctionID;

      // transfer premium
      depositPremium(auctionID,assetName,premium);

      // add bidders. participants and hashlocks must index to the same person.
      for (uint i = 0; i < participants.length; i++) {
        bidders[auctionID].push(participants[i]);
        hashLocks[auctionID][locks[i]] = participants[i];
      }

      // set up deadlines
      deadlines[auctionID].bid = startTime + DELTA;
      deadlines[auctionID].declaration = startTime + 2 * DELTA;
      deadlines[auctionID].challenge = startTime + (participants.length + 2) * DELTA;

      emit SetUp(
        block.timestamp, 
        auctionID, 
        msg.sender, 
        assetName, 
        premium, 
        participants, 
        locks, 
        DELTA, 
        startTime
      );
    }
    function depositPremium(
    bytes32 auctionID,
    address assetName, 
    uint premium) private{
        ERC20(assetName).transferFrom(msg.sender, address(this), premium);
        auctions[auctionID].currentpremium += premium;
        emit DepositPremium(
          block.timestamp, 
          auctionID, 
          msg.sender,
          premium, 
          msg.sender, 
          address(this),
          auctions[auctionID].currentpremium 
        );
  }

    // Participants will call this function to submit their bids.
    function bid(bytes32 auctionID, uint amount) public canBid(auctionID, amount) {
      ERC20(auctions[auctionID].assetName).transferFrom(msg.sender, address(this), amount);
      bids[auctionID][msg.sender] = amount;
      // need to update top bidder
      if (amount > auctions[auctionID].maxBid) {
        auctions[auctionID].maxBid = amount;
        auctions[auctionID].winner = msg.sender;
      }
      auctions[auctionID].currentbids += amount;

      emit Bid(
        block.timestamp, 
        auctionID, 
        msg.sender,
        amount,
        msg.sender,
        address(this)
      );
    }

    // Auctioneer will call this function to post the winning hashKey
    function declare(
      bytes32 auctionID, 
      bytes32 secret, 
      address[] memory path, 
      bytes32[] memory signatures) public canDeclare(auctionID, secret, path, signatures) {
      auctions[auctionID].hashKeys.push(HashKey(secret, path, signatures));

      emit Declaration(block.timestamp, 
        auctionID, 
        msg.sender,
        secret, 
        path
      );
    }

    // Participants will call this function to challenge the winner
    // if they see a different hashKey on the ticketAuction.
    function challenge(
      bytes32 auctionID, 
      bytes32 secret, 
      address[] memory path, 
      bytes32[] memory signatures) public canChallenge(auctionID, secret, path, signatures) {
      for (uint i = 0; i < auctions[auctionID].hashKeys.length; i++) {
        if (auctions[auctionID].hashKeys[i].secret == secret) {
          return;
        }
      }
      auctions[auctionID].hashKeys.push(HashKey(secret, path, signatures));

      emit Challenge(
        block.timestamp, 
        auctionID,
        msg.sender, 
        secret, 
        path
      );
    }

    // private functions called by settle for a party to redeem the coin
    function redeemBids(
      bytes32 auctionID, 
      address winner,
      uint amount) private canRedeemBids(auctionID, winner, amount) {
      ERC20(auctions[auctionID].assetName).transfer(auctions[auctionID].auctioneer, amount);
      auctions[auctionID].currentbids -= amount;
      emit RedeemBids(
          block.timestamp, 
          auctionID, 
          msg.sender,
          amount, 
          address(this),
          auctions[auctionID].auctioneer,
          auctions[auctionID].currentbids
      );
      
    }

     // private functions called by settle for a party to redeem the coin
    function refundBids(
      bytes32 auctionID, 
      address participant,
      uint amount) private canRefundBids(auctionID, participant, amount) {
      ERC20(auctions[auctionID].assetName).transfer(participant, amount);
      auctions[auctionID].currentbids -= amount;
      emit RefundBids(
          block.timestamp, 
          auctionID, 
          msg.sender,
          amount, 
          address(this),
          participant,
          auctions[auctionID].currentbids
      );
    }

    function refundPremium(
      bytes32 auctionID, 
      address participant,
      uint amount) private canRefundPremium(auctionID, participant, amount) {
      ERC20(auctions[auctionID].assetName).transfer(participant, amount);
      auctions[auctionID].currentpremium -= amount;
      emit RefundPremium(
          block.timestamp, 
          auctionID, 
          msg.sender,
          amount, 
          address(this),
          participant,
          auctions[auctionID].currentpremium
      );
    }
    function redeemPremium(
      bytes32 auctionID, 
      address participant,
      uint amount) private canRedeemPremium(auctionID, participant, amount) {
      ERC20(auctions[auctionID].assetName).transfer(participant, amount);
      auctions[auctionID].currentpremium -= amount;
      emit RedeemPremium(
          block.timestamp, 
          auctionID, 
          msg.sender,
          amount, 
          address(this),
          participant,
          auctions[auctionID].currentpremium
      );
    }

    // Any participating can call this function.
    function settle(bytes32 auctionID) public canSettle(auctionID) {
      // no bids
      if (auctions[auctionID].maxBid == 0) {
        // refund auctioneer's premium
        refundPremium(auctionID, auctions[auctionID].auctioneer, auctions[auctionID].expectedpremium);
        emit Settlement(
        block.timestamp,
        auctionID, 
        msg.sender,
        auctions[auctionID].hashKeys.length,
        auctions[auctionID].currentbids,
        auctions[auctionID].currentpremium
      );
        return;
      }
      // If block for success, else block for failure
      if (auctions[auctionID].hashKeys.length == 1 
      && hashLocks[auctionID][sha256(abi.encode(auctions[auctionID].hashKeys[0].secret))] == auctions[auctionID].winner) {
        // redeem auctioneer's premium
        refundPremium(auctionID, auctions[auctionID].auctioneer, auctions[auctionID].expectedpremium);
        for (uint i = 0; i < bidders[auctionID].length; i++) {
          // winning bid transfers to auctioneer, everyone else gets their bid redeemed.
          if (bidders[auctionID][i] == auctions[auctionID].winner) {
           redeemBids(auctionID, bidders[auctionID][i],  bids[auctionID][bidders[auctionID][i]]);
          } else {
            if(bids[auctionID][bidders[auctionID][i]]>0)
            // refund to non-winners
            {
              refundBids(auctionID,bidders[auctionID][i],bids[auctionID][bidders[auctionID][i]]);
            }
          }
        
        }
      } else {
        // everyone gets premium / i, where i is the total number of bidders.
        // bidders get their bids redeemed
        for (uint i = 0; i < bidders[auctionID].length; i++) {
          redeemPremium(auctionID,bidders[auctionID][i],auctions[auctionID].expectedpremium / bidders[auctionID].length);
          if(bids[auctionID][bidders[auctionID][i]]>0){
            refundBids(auctionID, bidders[auctionID][i], bids[auctionID][bidders[auctionID][i]]);
          }
        }
      }
      auctions[auctionID].settled = true;
      
      emit Settlement(
        block.timestamp,
        auctionID, 
        msg.sender,
        auctions[auctionID].hashKeys.length,
        auctions[auctionID].currentbids,
        auctions[auctionID].currentpremium
      );
      
    }
}