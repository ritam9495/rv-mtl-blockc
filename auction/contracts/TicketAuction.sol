// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./libraries/token/ERC20/ERC20.sol";

contract TicketAuction {

  // We will manipulate the DELTA variable (seconds) to see how sucessful the monitor is
    uint constant DELTA = 5000; //TODO: choose your DELTA (in milliseconds)

    // an Auction
    struct Auction {
      HashKey[] hashKeys;
      address auctioneer;
      address assetName;
      uint expectedAssetAmount;
      uint startTime;
      uint currentTicket;
      bool settled;
    }

    // various deadlines for phases of the protocol
    struct Deadlines {
      uint declaration;
      uint challenge;
    }

    // the hashKey triple, as defied in the paper.
    struct HashKey {
      bytes32 secret;
      address[] path;
      bytes32[] signatures;
    }

    // Mappings that store information for our contract
    mapping(bytes32 => Auction) auctions;
    mapping(bytes32 => mapping(address => bool)) bidders;
    mapping(bytes32 => Deadlines) deadlines;
    mapping(bytes32 => mapping(bytes32 => address)) hashLocks;

    event SetUp(
      uint timeStamp,
      bytes32 auctionID,
      address auctioneer,
      address assetName,
      uint expectedAssetAmount,
      address[] participants,
      bytes32[] hashLocks,
      uint delta,
      uint startTime
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
    event EscrowTicket(
      uint timestamp,
      bytes32 auctionID,
      address messageSender,
      uint amount,
      address transferFrom,
      address transferTo,
      uint currentTicket
    );
    event RedeemTicket(
      uint timestamp,
      bytes32 auctionID,
      address messageSender,
      uint amount,
      address transferFrom,
      address transferTo,
      uint currentTicket
    );
    event RefundTicket(
      uint timestamp,
      bytes32 auctionID,
      address messageSender,
      uint amount,
      address transferFrom,
      address transferTo,
      uint currentTicket
    );

    event Settlement(
      uint timeStamp,
      bytes32 auctionID,
      address messageSender,
      uint hashKeysLength,
      uint currentTicket
    );

    modifier canSetup(bytes32 auctionID, address assetName, uint assetAmount) {
      require(auctions[auctionID].auctioneer == address(0), "[canSetup]: auctions[auctionID].auctioneer != address(0)");
      require(ERC20(assetName).balanceOf(msg.sender) >= assetAmount, "[canSetup] balance not enough");
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
      require(block.timestamp <= deadlines[auctionID].challenge, "[canChallenge] did not complete action in time");
      require(bidders[auctionID][msg.sender] != false, "[canChallenge] not a bidder");
      require(hashLocks[auctionID][sha256(abi.encode(secret))] != address(0), "[canChallenge]: not a valid secret");
      // make sure that your challenge is made in time (dependent on the path/signature length)
      require(block.timestamp <= auctions[auctionID].startTime + DELTA * (path.length + 1));
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
     modifier canRefundTicket(
      bytes32 auctionID, 
      address participant,
      uint amount){
      require(block.timestamp >= deadlines[auctionID].challenge, "[canRefundTicket] did not wait challenge to wait");
      require(auctions[auctionID].currentTicket  == amount, "[canRefundTicket]: not the correct amount");
      require(auctions[auctionID].auctioneer  == participant, "[canRefundTicket]: not refunding to auctioneer");
      require(auctions[auctionID].hashKeys.length != 1, "[canRefundTicket]: hashkeys.length ==1");
      _;
    }
    modifier canRedeemTicket(
      bytes32 auctionID, 
      address participant,
      uint amount){
      require(block.timestamp >= deadlines[auctionID].challenge, "[canRedeemTicket] did not wait challenge to wait");
      require(auctions[auctionID].currentTicket == amount, "[canRedeemTicket]: not the correct amount");
      require(auctions[auctionID].hashKeys.length == 1, "[canRedeemTicket]: hashkeys.length !=1");
      require(hashLocks[auctionID][sha256(abi.encode(auctions[auctionID].hashKeys[0].secret))] == participant, "[canRedeemTicket]: not transfer to winner");
      _;
    }

    modifier canSettle(bytes32 auctionID) {
      require(auctions[auctionID].auctioneer != address(0), "auctioneer is 0 address");
      if (auctions[auctionID].hashKeys.length == 1) {
        require(hashLocks[auctionID][sha256(abi.encode(auctions[auctionID].hashKeys[0].secret))] != address(0), "bidder address is 0");
      }
      require(!auctions[auctionID].settled, "[canSettle] auction was already settled");
      require(block.timestamp > deadlines[auctionID].challenge, "[canSettle] tried to settle before challenge period concluded");
      require(bidders[auctionID][msg.sender] == true || msg.sender == auctions[auctionID].auctioneer, "[canSettle] commiter is not a participant in the auction");
      _;
    }

    // Auctioneer will call this to set up the auction
    function setup(
      bytes32 auctionID, 
      uint assetAmount, 
      address[] memory participants,
      bytes32[] memory locks,
      address assetName,
      uint startTime) public canSetup(auctionID, assetName, assetAmount) {
    
      auctions[auctionID].expectedAssetAmount = assetAmount;
      auctions[auctionID].currentTicket = 0;

      auctions[auctionID].auctioneer = msg.sender;
      auctions[auctionID].assetName = assetName;
      auctions[auctionID].startTime = startTime;
      // escrow ticket
      escrowTicket(auctionID, assetName, assetAmount);

      // mapping participants with the hashLocks (called locks here to avoid naming conflicts)
      for (uint i = 0; i < participants.length; i++) {
        bidders[auctionID][participants[i]] = true;
        hashLocks[auctionID][locks[i]] = participants[i];
      } 

      // set up deadlines
      deadlines[auctionID].declaration = startTime + 2 * DELTA;
      deadlines[auctionID].challenge = startTime + (participants.length + 2) * DELTA;
      
      emit SetUp(
        block.timestamp, 
        auctionID, 
        msg.sender, 
        assetName, 
        assetAmount, 
        participants, 
        locks, 
        DELTA, 
        startTime
      );
    }
    function escrowTicket(
    bytes32 auctionID,
    address assetName, 
    uint amount) private{
        ERC20(assetName).transferFrom(msg.sender, address(this), amount);
        auctions[auctionID].currentTicket += amount;
        emit EscrowTicket(
          block.timestamp, 
          auctionID, 
          msg.sender,
          amount, 
          msg.sender, 
          address(this),
          auctions[auctionID].currentTicket
        );
  }

    // Auctioneer will call this function to post the winning hashKey
    function declare(
      bytes32 auctionID, 
      bytes32 secret, 
      address[] memory path, 
      bytes32[] memory signatures
    ) public canDeclare(auctionID, secret, path, signatures) {
      // add hashKey
      auctions[auctionID].hashKeys.push(HashKey(secret, path, signatures));

      emit Declaration(block.timestamp, 
        auctionID, 
        msg.sender,
        secret, 
        path
      );
    }

    // Bidders will call this function to challenge the winner
    // if they see a different hashKey on the coinAuction.
    function challenge(
      bytes32 auctionID, 
      bytes32 secret, 
      address[] memory path, 
      bytes32[] memory signatures
    ) public canChallenge(auctionID, secret, path, signatures) {
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
    //private functions to be called by settle
    function refundTicket(
      bytes32 auctionID, 
      address participant,
      uint amount) private canRefundTicket(auctionID, participant, amount) {
      ERC20(auctions[auctionID].assetName).transfer(participant, amount);
      auctions[auctionID].currentTicket-= amount;
      emit RefundTicket(
          block.timestamp, 
          auctionID, 
          msg.sender,
          amount, 
          address(this),
          participant,
          auctions[auctionID].currentTicket
      );
    }
    //private functions to be called by settle
    function redeemTicket(
      bytes32 auctionID, 
      address participant,
      uint amount) private canRedeemTicket(auctionID, participant, amount) {
      ERC20(auctions[auctionID].assetName).transfer(participant, amount);
      auctions[auctionID].currentTicket-= amount;
      emit RedeemTicket(
          block.timestamp, 
          auctionID, 
          msg.sender,
          amount, 
          address(this),
          participant,
          auctions[auctionID].currentTicket
      );
    }

    // All participants can call this function.
    function settle(bytes32 auctionID) public canSettle(auctionID) {
      if (auctions[auctionID].hashKeys.length == 1) {
        redeemTicket(auctionID, hashLocks[auctionID][sha256(abi.encode(auctions[auctionID].hashKeys[0].secret))], auctions[auctionID].expectedAssetAmount);
      } else {
        // refund
        refundTicket(auctionID,auctions[auctionID].auctioneer,auctions[auctionID].expectedAssetAmount);
      }
      auctions[auctionID].settled = true;
      
      emit Settlement(
        block.timestamp,
        auctionID,
        msg.sender,
        auctions[auctionID].hashKeys.length,
        auctions[auctionID].currentTicket

      );
    }
}