// Some functions based off of fair-atomic-swap/src/atomicswap/eip2266/ERC2266Swap.sol
// Copyright (c) 2019 Chris Haoyu LIN, Runchao HAN, Jiangshan YU
// SPDX-License-Identifier: UNLICENSED

// todo: fix all states to be different names

pragma solidity ^0.8.10;

import "./libraries/token/ERC20/ERC20.sol";

contract CherrySwap {

    /**
        We will manipulate the DELTA variable (seconds) to see how sucessful the monitor is
     */

    uint constant numParticipants = 3;
    uint constant numLeaders = 1;
    uint constant numEdges = 3;
    uint constant maxNumPaths = 1;
    uint constant maxPathLength = 3;
    uint  DELTA ; //TODO: choose your DELTA
    /**
     * Mappings that store our swap details.
     */
    mapping(bytes32 => bool) hashkeyRedeemed;
    mapping(bytes32 => Swap) public swaps;
    mapping(bytes32 => Escrow) public escrows;
    mapping(bytes32 => EscrowPremium) public escrowPremiums;
    mapping(bytes32 => RedemptionPremium) public redemptionPremiums;

    //store
    struct Swap {
        bytes32[numLeaders] leaderPremiumHashLock;
        bytes32[numLeaders] leaderEscrowHashLock;
        address assetName;
        uint timeout;
        bool[6] stepsTaken;
        address sender;
        address receiver;
    }

    /**
     * The Escrow struct keeps track of the escrowed Asset
     */
    struct Escrow {
        //type of asset
        uint expected;
        uint current;
        //the deadline is for escrowing
        uint deadline;
        //the timeout is for redeeming
        uint timeout;
    }

    /**
     * The Premium struct keeps track of the deposited premium.
     */
    struct EscrowPremium {
        uint expected;
        uint current;
        uint deadline;
        uint timeout;
    }

    struct RedemptionPremium {
        bytes32 hashlock;
        uint expected;
        uint current;
        uint deadline;
        uint timeout;
        address[] path;
    }

////// event interfaces are defined as below

    event SetUp(
        address assetName,
        address contractAddress,
        uint timestamp,
        uint startTime,
        uint delta,
        bytes32 escrowHashLock,
        address payable sender,
        address payable receiver
    );

    event EscrowPremiumDeposited(
        uint timestamp,
         address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentEscrowPremiumAmount
    );
    event RedemptionPremiumDeposited(
        uint timestamp,
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentRedemptionPremiumAmount
    );  
    

    event AssetEscrowed (
        uint timestamp,
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentEscrowAmount
    );
    event HashLockUnlocked(
        uint timestamp,
        address messageSender,
        bytes32 hashlock,
        address[] path
    );


    event EscrowPremiumRefunded(
        uint timestamp,
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentEscrowPremiumAmount

    );

    event EscrowPremiumRedeemed(
        uint timestamp,
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentEscrowPremiumAmount
    );

    event RedemptionPremiumRedeemed(
        uint timestamp,
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        bytes32 hashlock,
        uint currentRedemptionPremiumAmount

    );
    event RedemptionPremiumRefunded(
        uint timestamp,
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        bytes32 hashlock,
        uint currentRedemptionPremiumAmount
    );

    event AssetRedeemed(
        uint timestamp,
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentEscrowAmount
    );

    event AssetRefunded(
        uint timestamp,
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentEscrowAmount
    );
    event AllAssetsSettled(
        uint timestamp,
        address assetName,
        uint currentEscrowAmount,
        uint currentEscrowPremiumAmount,
        uint currentRedemptionPremiumAmount
    );


//// modifiers below


     modifier canSetup(bytes32 escrowHashLock) {
        require(swaps[escrowHashLock].stepsTaken[0] == false, "[canSetup], already setup");
        _;
    }
    modifier canDepositEscrowPremium(bytes32 escrowHashLock){
        require(msg.sender == swaps[escrowHashLock].sender,"[canDepositEscrowPremium], not right sender:");
        require(swaps[escrowHashLock].stepsTaken[0] == true && swaps[escrowHashLock].stepsTaken[1] == false,"[canDepositEscrowPremium]: contract not setup");
        require(ERC20(swaps[escrowHashLock].assetName).balanceOf(msg.sender) >= escrowPremiums[escrowHashLock].expected, "[canDepositEscrowPremium]: not enough balance");
        require(block.timestamp <= escrowPremiums[escrowHashLock].deadline, "[canDepositEscrowPremium]: did not deposit escrow premium in time");
        _;
    }
    modifier canDepositRedemptionPremium(bytes32 escrowHashLock, bytes32 premiumHashLock, bytes32 preimage, address[] memory path){
        require(msg.sender == swaps[escrowHashLock].receiver, "[canDepositRedemptionPremium], incorrect sender");
        require(swaps[escrowHashLock].stepsTaken[1] == true, "[canDepositRedemptionPremium], escrow premium not deposited on contract");
        require(swaps[escrowHashLock].stepsTaken[2] == false, "[canDepositRedemptionPremium], redemption premium already deposited on contract");
        require(sha256(abi.encode(preimage)) == swaps[escrowHashLock].leaderPremiumHashLock[0], "[canDepositRedemptionPremium], incorrect secret");
        require(ERC20(swaps[escrowHashLock].assetName).balanceOf(msg.sender) >= redemptionPremiums[escrowHashLock].expected, "[canDepositRedemptionPremium], not enough currency");
        require(block.timestamp <= redemptionPremiums[escrowHashLock].deadline, "[canDepositRedemptionPremium], did not deposit redemption premium in time");
        _;
    }
    modifier canEscrowAsset(bytes32 escrowHashLock) {
        require(msg.sender == swaps[escrowHashLock].sender, "[canEscrowAsset], incorrect sender");
        require(swaps[escrowHashLock].stepsTaken[2] == true, "[canEscrowAsset], redemption premium not deposited");
        require(swaps[escrowHashLock].stepsTaken[3] == false, "[canEscrowAsset], asset already escrowed");
        require(ERC20(swaps[escrowHashLock].assetName).balanceOf(msg.sender) >= escrows[escrowHashLock].expected, "[canEscrowAsset], not enough currency");
        require(block.timestamp <= escrows[escrowHashLock].deadline, "[canEscrowAsset], did not escrow asset in time");
        _;
    }
    modifier canUnlockHashLock(bytes32 escrowHashLock, bytes32 preimage, address[] memory path)
    {
        require(msg.sender == swaps[escrowHashLock].receiver, "[canUnlockHashLock], incorrect sender");
        require(swaps[escrowHashLock].stepsTaken[4] == false, "[canUnlockHashLock], HashLock already unlocked");
        require(swaps[escrowHashLock].stepsTaken[2] == true, "[canUnlockHashLock], redemption premium not deposited");
        require(block.timestamp <= redemptionPremiums[escrowHashLock].timeout, "[canUnlockHashLock], redemption premium timed out");
        require(sha256(abi.encode(preimage)) == swaps[escrowHashLock].leaderEscrowHashLock[0], "[canUnlockHashLock], wrong secret provided");
        address[] memory stored_path = redemptionPremiums[escrowHashLock].path;
        require(stored_path.length == path.length, "[canUnlockHashLock], path lengths not the same");
        for(uint i = 0; i < path.length; i++)
        {
            require(stored_path[i] == path[i], "[canUnlockHashLock] paths not the same");
        }
        _;
    }
    modifier canRedeemAsset(bytes32 escrowHashLock) {
        require(msg.sender == swaps[escrowHashLock].receiver, "[canRedeemAsset], incorrect sender");
        require(swaps[escrowHashLock].stepsTaken[4] == true, "[canRedeemAsset], hashLock not unlocked");
        require(block.timestamp <= escrows[escrowHashLock].timeout, "[canRedeemAsset], asset timed out");
        require(escrows[escrowHashLock].current == escrows[escrowHashLock].expected, "[canRedeemAsset], not enough asset was escrowed");
        _;
    }

    modifier canRefundAsset(bytes32 escrowHashLock) {
        require(swaps[escrowHashLock].stepsTaken[3] == true, "[canRefundAsset], Asset not escrowed");
        require(swaps[escrowHashLock].stepsTaken[4] == false, "[canRefundAsset], hashLock already unlocked");
        require(block.timestamp > escrows[escrowHashLock].timeout, "[canRefundAsset], Escrow has not timed out yet");
        require(escrows[escrowHashLock].current == escrows[escrowHashLock].expected, "[canRefundAsset], not enough asset was escrowed");
        //if the asset is escrowed and the timeout has passed, allow them to get their asset back
        _;
    }


    modifier canRedeemEscrowPremium(bytes32 escrowHashLock) {
        require(swaps[escrowHashLock].stepsTaken[2] == true, "[canRedeemEscrowPremium], redemption premium not deposited");
        require(swaps[escrowHashLock].stepsTaken[1] == true, "[canRedeemEscrowPremium], escrow premium not deposited on contract");
        require(swaps[escrowHashLock].stepsTaken[3] == false, "[canRedeemEscrowPremium], asset already escrowed");
        require(block.timestamp > escrows[escrowHashLock].deadline, "[canRedeemEscrowPremium], deadline not passed");
        require(escrowPremiums[escrowHashLock].current == escrowPremiums[escrowHashLock].expected, "[canRedeemEscrowPremium] not enough escrow premium deposited");
        _;
    }

    modifier canRedeemRedemptionPremium(bytes32 escrowHashLock) {
        require(swaps[escrowHashLock].stepsTaken[2] == true, "[canRedeemRedemptionPremium], redemption premium not deposited");//Redemption Premium Deposited
        require(swaps[escrowHashLock].stepsTaken[4] == false, "[canRedeemRedemptionPremium], hashLock already unlocked"); //Asset not redeemed
        require(block.timestamp > redemptionPremiums[escrowHashLock].timeout, "[canRedeemRedemptionPremium], redemption premium has not timed out");
        require(redemptionPremiums[escrowHashLock].current == redemptionPremiums[escrowHashLock].expected, "[canRedeemRedemptionPremium], not enough redemption premium deposited");
        _;
    }
    modifier canRefundEscrowPremium(bytes32 escrowHashLock) {
        require((block.timestamp > escrowPremiums[escrowHashLock].timeout && swaps[escrowHashLock].stepsTaken[2] == false) 
                || (swaps[escrowHashLock].stepsTaken[3] == true), "[canRefundEscrowPremium], the deadline passed and the receiver did not post a redemption premium or if the asset has been escrowed");
                //Allow refund to the sender if the deadline passed and the receiver did not post a redemption premium or if the asset has been escrowed
        require(escrowPremiums[escrowHashLock].current == escrowPremiums[escrowHashLock].expected, "[canRefundEscrowPremium], not enough asset was deposited for the escrow premium");
        _;
    }
    modifier canRefundRedemptionPremium(bytes32 escrowHashLock) {
        require(swaps[escrowHashLock].stepsTaken[4] == true, "[canRefundRedemptionPremium], hashLock already unlocked");
        require(redemptionPremiums[escrowHashLock].current == redemptionPremiums[escrowHashLock].expected, "[canRefundRedemptionPremium], not enough redemption premium deposited");
        _;
    }
    modifier canSettleAllAssets(bytes32 escrowHashLock) {
        require(block.timestamp > escrows[escrowHashLock].timeout, "[canSettleAllAssets] block.timestamp <= escrows[escrowHashLock].timeout");
        _;
    }

    function setup(uint expectedEscrowAmount,
                    uint expectedEscrowPremiumAmount,
                    address payable sender,
                    address payable receiver,
                    address assetName,
                    bytes32 escrowHashLock,
                    bytes32 premiumHashLock,
                    uint startTime,
                    address[] memory path,
                    uint delta)
        public payable canSetup(escrowHashLock){

        DELTA = delta;
        //set up swap mapping
        swaps[escrowHashLock].assetName = assetName;
        swaps[escrowHashLock].stepsTaken[0] = true; //TODO refactor into steps taken array
        swaps[escrowHashLock].sender = sender;
        swaps[escrowHashLock].receiver = receiver;
        swaps[escrowHashLock].leaderPremiumHashLock[0] = premiumHashLock;
        swaps[escrowHashLock].leaderEscrowHashLock[0] = escrowHashLock;
        swaps[escrowHashLock].timeout = startTime + 10 * DELTA;

        //set up escrow mapping
        escrows[escrowHashLock].current = 0;
        escrows[escrowHashLock].expected = expectedEscrowAmount;
        escrows[escrowHashLock].deadline = startTime + 9 * DELTA;
        escrows[escrowHashLock].timeout = startTime + 10 * DELTA;

        //set up premium mapping
        escrowPremiums[escrowHashLock].current = 0;
        escrowPremiums[escrowHashLock].expected = expectedEscrowPremiumAmount;
        escrowPremiums[escrowHashLock].deadline = startTime + 3 * DELTA;
        escrowPremiums[escrowHashLock].timeout = startTime + 9 * DELTA;

        redemptionPremiums[escrowHashLock].path = path;
        redemptionPremiums[escrowHashLock].current = 0;
        redemptionPremiums[escrowHashLock].expected = 4-path.length;//1,2,3, the cost
        redemptionPremiums[escrowHashLock].deadline = startTime + (3+path.length)* DELTA;//TODO: fix that later
        redemptionPremiums[escrowHashLock].timeout = startTime + (9+path.length)* DELTA;//TODO: fix that later;     
        
        emit SetUp(
            swaps[escrowHashLock].assetName,
            address(this),
            block.timestamp,
            startTime,
            DELTA,
            escrowHashLock,
            sender,
            receiver

        );

    }
 function depositEscrowPremium(bytes32 escrowHashLock) public payable canDepositEscrowPremium(escrowHashLock)
    {
        ERC20(swaps[escrowHashLock].assetName).transferFrom(swaps[escrowHashLock].sender, address(this), escrowPremiums[escrowHashLock].expected);
        escrowPremiums[escrowHashLock].current = escrowPremiums[escrowHashLock].expected;
        swaps[escrowHashLock].stepsTaken[1] = true;

        emit EscrowPremiumDeposited(
            block.timestamp,
            msg.sender,
            escrowPremiums[escrowHashLock].current,
            swaps[escrowHashLock].sender, 
            address(this),
            escrowPremiums[escrowHashLock].current

        );
    }

    function depositRedemptionPremium(bytes32 escrowHashLock, bytes32 premiumHashLock, bytes32 preimage, address[] memory path) public payable canDepositRedemptionPremium(escrowHashLock, premiumHashLock, preimage, path)
    {
        ERC20(swaps[escrowHashLock].assetName).transferFrom(swaps[escrowHashLock].receiver, address(this), redemptionPremiums[escrowHashLock].expected);
        redemptionPremiums[escrowHashLock].current = redemptionPremiums[escrowHashLock].expected;
        swaps[escrowHashLock].stepsTaken[2] = true;

        emit RedemptionPremiumDeposited(
            block.timestamp,
            msg.sender,
            redemptionPremiums[escrowHashLock].current,
            swaps[escrowHashLock].receiver, 
            address(this),
            redemptionPremiums[escrowHashLock].current
        );
    }

    function escrowAsset(bytes32 escrowHashLock) public payable canEscrowAsset(escrowHashLock) {
        ERC20(swaps[escrowHashLock].assetName).transferFrom(swaps[escrowHashLock].sender, address(this), escrows[escrowHashLock].expected);
        escrows[escrowHashLock].current = escrows[escrowHashLock].expected;
        swaps[escrowHashLock].stepsTaken[3] = true;
        emit AssetEscrowed(
            block.timestamp,
            msg.sender,
            escrows[escrowHashLock].current,
            swaps[escrowHashLock].sender, 
            address(this),
            escrows[escrowHashLock].current   
        );
        refundEscrowPremium(escrowHashLock);
    }


    function unlockHashlock(bytes32 escrowHashLock, bytes32 preimage, address[] memory path) public payable canUnlockHashLock(escrowHashLock, preimage, path)
    {      
        swaps[escrowHashLock].stepsTaken[4] = true;
        emit HashLockUnlocked(
            block.timestamp,
            msg.sender,
            escrowHashLock,
            path  
        );
        if(swaps[escrowHashLock].stepsTaken[2]==true)
        {
            refundRedemptionPremium(escrowHashLock);
        }
        // we need to call refundredemptionpremium to get back the corresponding redemption premium

        if(swaps[escrowHashLock].stepsTaken[3]==true)
        {
            redeemAsset(escrowHashLock);
        }

    }
    // private function
    function redeemAsset(bytes32 escrowHashLock) private canRedeemAsset(escrowHashLock) {
        ERC20(swaps[escrowHashLock].assetName).transfer(swaps[escrowHashLock].receiver, escrows[escrowHashLock].current);
        escrows[escrowHashLock].current = 0;
        emit AssetRedeemed(
            block.timestamp,
            msg.sender,
            escrows[escrowHashLock].expected,
            address(this),
            swaps[escrowHashLock].receiver,
            escrows[escrowHashLock].current    
        );
    }
    // private function
    function refundAsset(bytes32 escrowHashLock) private canRefundAsset(escrowHashLock) {
        ERC20(swaps[escrowHashLock].assetName).transfer(swaps[escrowHashLock].sender, escrows[escrowHashLock].current);
        escrows[escrowHashLock].current = 0;
        emit AssetRefunded(
            block.timestamp,
            msg.sender,
            escrows[escrowHashLock].expected,
            address(this),
            swaps[escrowHashLock].sender,
            escrows[escrowHashLock].current   
        );
    }
    // private function
    function redeemEscrowPremium(bytes32 escrowHashLock) private canRedeemEscrowPremium(escrowHashLock){
        ERC20(swaps[escrowHashLock].assetName).transfer(swaps[escrowHashLock].receiver, escrowPremiums[escrowHashLock].current);
        escrowPremiums[escrowHashLock].current = 0;
        emit EscrowPremiumRedeemed(
            block.timestamp,
            msg.sender,
            escrowPremiums[escrowHashLock].expected,
            address(this),
            swaps[escrowHashLock].receiver,
            escrowPremiums[escrowHashLock].current
  
        );
    }
    //private function
    function refundEscrowPremium(bytes32 escrowHashLock) private canRefundEscrowPremium(escrowHashLock){
        ERC20(swaps[escrowHashLock].assetName).transfer(swaps[escrowHashLock].sender, escrowPremiums[escrowHashLock].current);
        escrowPremiums[escrowHashLock].current = 0;
        emit EscrowPremiumRefunded(
            block.timestamp,
            msg.sender,
            escrowPremiums[escrowHashLock].expected,
            address(this),
            swaps[escrowHashLock].sender,
            escrowPremiums[escrowHashLock].current
            
        );
    }
    // private function
    function redeemRedemptionPremium(bytes32 escrowHashLock) private  canRedeemRedemptionPremium(escrowHashLock){
        ERC20(swaps[escrowHashLock].assetName).transfer(swaps[escrowHashLock].sender, redemptionPremiums[escrowHashLock].current);
        redemptionPremiums[escrowHashLock].current = 0;
        emit RedemptionPremiumRedeemed(
            block.timestamp,
            msg.sender,
            redemptionPremiums[escrowHashLock].expected,
            address(this),
            swaps[escrowHashLock].sender,
            escrowHashLock,
            redemptionPremiums[escrowHashLock].current    
        );
    }

    function refundRedemptionPremium(bytes32 escrowHashLock) private  canRefundRedemptionPremium(escrowHashLock){
        ERC20(swaps[escrowHashLock].assetName).transfer(swaps[escrowHashLock].receiver, redemptionPremiums[escrowHashLock].current);
        
        redemptionPremiums[escrowHashLock].current = 0;
        emit RedemptionPremiumRefunded(
            block.timestamp,
            msg.sender,
            redemptionPremiums[escrowHashLock].expected,
            address(this),
            swaps[escrowHashLock].receiver,
            escrowHashLock,
            redemptionPremiums[escrowHashLock].current   
        );
    }

    function settleAllAssets(bytes32 escrowHashLock) public payable canSettleAllAssets(escrowHashLock){
        if (swaps[escrowHashLock].stepsTaken[1]&&!swaps[escrowHashLock].stepsTaken[2])
        {
            refundEscrowPremium(escrowHashLock);
        }
        if (swaps[escrowHashLock].stepsTaken[1]&&swaps[escrowHashLock].stepsTaken[2]&&!swaps[escrowHashLock].stepsTaken[3])
        {
            redeemEscrowPremium(escrowHashLock);
        } 
        if (swaps[escrowHashLock].stepsTaken[3]&&!swaps[escrowHashLock].stepsTaken[4])
        {
            redeemRedemptionPremium(escrowHashLock);
            refundAsset(escrowHashLock);
        } 
        emit AllAssetsSettled(block.timestamp,
            swaps[escrowHashLock].assetName,
            escrows[escrowHashLock].current,
            escrowPremiums[escrowHashLock].current,
            redemptionPremiums[escrowHashLock].current  
            );
    }

}