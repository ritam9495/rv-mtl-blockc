// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./libraries/token/ERC20/ERC20.sol";

contract TwoPartySwapBanana {

    /**
    We will manipulate the DELTA variable (seconds) to see how sucessful the monitor is
     */
    uint DELTA; //TODO: choose your DELTA (in milliseconds)

    /**
    The BananaSwap struct keeps track of participants and swap details
     */
    struct BananaSwap {
        address payable receiver;
        address payable sender;
        bytes32 hashLock;
        address assetName;
        bool[] stepsTaken;
    }

    /**
    The Escrow struct keeps track of the escrowed Asset
     */
    struct Escrow {
        uint expected;
        uint current;
        uint deadline;
        uint timeout;
    }

    /**
    The Premium struct keeps track of the deposited premium.
     */
    struct Premium {
        uint expected;
        uint current;
        uint deadline;
    }

    /**
    Mappings that store our swap details.
     */
    mapping(bytes32 => BananaSwap) public swaps;
    mapping(bytes32 => Escrow) public escrows;
    mapping (bytes32 => Premium) public premiums;

    /**
    On setup, we need to know the hashlock, participants, and expected 
    values for the premium and asset. For monitoring purposes, we'd also like to 
    know the delta.
     */
    event SetUp(
        address assetName,
        address contractAddress,
        uint timestamp,
        bytes32 hashLock,
        address payable receiver,
        address payable sender, 
        uint expectedPremium,
        uint currentPremium,
        uint expectedAsset,
        uint currentAsset,
        uint delta,
        uint startTime
    );

    /**
    Once Bob deposits his premium, we want to check that he deposited the correct amount.
     */
    event PremiumDeposited(
        uint timestamp,
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    /**
    Once Alice escrows her asset, we want to check that she escrowed the correct amount.
     */
    event AssetEscrowed (
        uint timestamp,
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    /**
    If the swap succeeds, Bob will collect his asset.
     */
    event AssetRedeemed(
        uint timestamp,
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    /**
    If the swap succeeds, Bob will get his premium refunded.
     */
    event PremiumRefunded(
        uint timestamp,
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    /**
    If the swap fails, Alice will redeem Bob's premium after the timout deadline.
     */
    event PremiumRedeemed(
        uint timestamp,
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    /**
    If the swap fails, Alice can get her asset back after the timout deadline.
     */
    event AssetRefunded(
        uint timestamp,
        address messageSender,
        uint amount,
        address transferFrom,
        address transferTo,
        uint currentPremium,
        uint currentAsset
    );

    event AllAssetsSettled(
        uint timestamp,
        address assetName,
        uint currentPremium,
        uint currentAsset
    );
    /**
    modifies the setup function below, ensuring that the start state of the contract is clean.
    Since Solidity defaults to 0 (which is not a possible user address), we can check that both 
    Alice and Bob have the 0 address. If not, then this is an existing swap.
     */
      modifier canSetup(bytes32 hashLock) {
        require(swaps[hashLock].sender == address(0), "[canSetup]: swaps[hashLock].sender != address(0)");
        require(swaps[hashLock].receiver == address(0), "[canSetup]: swaps[hashLock].receiver != address(0)");
        _;
    }

    /**
    modifies the depositPremium function below, ensuring that the sender is Bob, no steps have
    been taken, the current premium is 0, Bob has enough funding, and that the action is 
    performed in time.
     */
    modifier canDepositPremium(bytes32 hashLock) {
        require(block.timestamp <= premiums[hashLock].deadline, "[canDepositPremium] did not complete action in time");
        require(msg.sender == swaps[hashLock].receiver, "[canDepositPremium] msg.sender is not Bob");
        require(!swaps[hashLock].stepsTaken[0], "[canDepositPremium]: appropriate steps not taken");
        require(premiums[hashLock].current == 0, "[canDepositPremium] premiums[hashLock].current != 0");
        require(ERC20(swaps[hashLock].assetName).balanceOf(msg.sender) >= premiums[hashLock].expected, "bob didn't have a large enough balance");
        _;
    }

    /**
    modifies the escrowAsset function below, ensuring that the sender is Alice, only the first step has been taken 
    (which is Bob depositing his premium), the premium is actually deposited, the asset is not yet escrowed, 
    Alice has enough of the asset, and she performs the action in time.
     */
    modifier canEscrowAsset(bytes32 hashLock) {
        require(block.timestamp <= escrows[hashLock].deadline, "[canEscrowAsset]: did not complete action in time");
        require(msg.sender == swaps[hashLock].sender, "[canEscrowAsset]: not alice");
        require(swaps[hashLock].stepsTaken[0] && !swaps[hashLock].stepsTaken[1], "[canEscrowAsset]: appropriate steps not taken");
        require(premiums[hashLock].current == premiums[hashLock].expected, "[canEscrowAsset]: premiums[hashLock].current != premiums[hashLock].expected");
        require(escrows[hashLock].current == 0, "[canEscrowAsset]: asset not escrowed");
        require(ERC20(swaps[hashLock].assetName).balanceOf(msg.sender) >= escrows[hashLock].expected);
        _;
    }

    /**
    modifies the redeemAsset function below, ensuring that the sender is Bob, only the first and second steps have
    been taken, the hashLock's preimage is correct, and the action is performed in time.
     */
    modifier canRedeemAsset(bytes32 preimage, bytes32 hashLock) {
        require(block.timestamp <= escrows[hashLock].timeout, "[canRedeemAsset]: did not complete action in time");
        require(msg.sender == swaps[hashLock].receiver, "[canRedeemAsset]: not bob");
        require(swaps[hashLock].stepsTaken[0] && swaps[hashLock].stepsTaken[1] && !swaps[hashLock].stepsTaken[2], "[canRedeemAsset]: appropriate steps not taken");
        require(sha256(abi.encode(preimage)) == hashLock, "preimage did not hash to hashLock");
        require(escrows[hashLock].current == escrows[hashLock].expected, "[canRedeemAsset]: escrows[hashLock].current != escrows[hashLock].expected");
        _;
    }

    /**
    modifies the refundAsset function below, ensuring that the sender is Alice, only the first and second steps 
    have been taken, the premimum is there to redeem, the hashLock's preimage is correct, and Bob missed the 
    timeout to redeem his asset.
     */
    modifier canRefundAsset(bytes32 hashLock) {
        require(block.timestamp > escrows[hashLock].timeout, "[canRefundAsset]: did not complete action in time");
        require(swaps[hashLock].stepsTaken[0] && swaps[hashLock].stepsTaken[1] && !swaps[hashLock].stepsTaken[2], "[canRefundAsset]: appropriate steps not taken");
        require(escrows[hashLock].current == escrows[hashLock].expected, "[canRefundAsset]: escrows[hashLock].current != escrows[hashLock].expected");
        _;
    }

    /**
    modifies the refundPremium function below, ensuring that the sender is Bob, only the first step was taken, the 
    asset was never escrowed, the premium exists, and we are past the deadline to escrow the asset.
     */
    modifier canRefundPremium(bytes32 hashLock) {
        require((swaps[hashLock].stepsTaken[0] && !swaps[hashLock].stepsTaken[1]) || swaps[hashLock].stepsTaken[2], "[canRefundPremium]: appropriate steps not taken");
        require(premiums[hashLock].current == premiums[hashLock].expected, "[canRefundPremium]: premiums[hashLock].current != premiums[hashLock].expected");
        _;
    }
   modifier canRedeemPremium(bytes32 hashLock) {
        require(block.timestamp > escrows[hashLock].timeout, "[canRedeemPremium]: did not wait to timeout");
        require(swaps[hashLock].stepsTaken[0] && swaps[hashLock].stepsTaken[1] && !swaps[hashLock].stepsTaken[2], "[canRedeemPremium]: appropriate steps not taken");
        require(premiums[hashLock].current == premiums[hashLock].expected, "[canRedeemPremium]: premiums[hashLock].current != premiums[hashLock].expected");
        _;
    }

    modifier canSettleAllAssets(bytes32 hashLock) {
        require(block.timestamp > escrows[hashLock].timeout, "[canSettleAllAssets]: tried to settle before timeout");
        _;
    }
   
    function setup(uint expectedEscrowBob,
                    uint expectedPremiumAlice,
                    address payable receiver,
                    address payable sender,
                    address assetName,
                    bytes32 hashLock,
                    uint startTime,
                    uint delta)
        public payable canSetup(hashLock) {

        DELTA = delta;

        //set up swap mapping
        swaps[hashLock].hashLock = hashLock;
        swaps[hashLock].assetName = assetName;
        swaps[hashLock].receiver = receiver;
        swaps[hashLock].sender = sender;
        swaps[hashLock].stepsTaken = new bool[](3);

        //set up escrow mapping
        escrows[hashLock].expected = expectedEscrowBob;
        escrows[hashLock].deadline = startTime + 4 * DELTA;
        escrows[hashLock].timeout = startTime + 5 * DELTA;
        
        //set up premium mapping
        premiums[hashLock].expected = expectedPremiumAlice;
        premiums[hashLock].deadline = startTime + 1 * DELTA;

        emit SetUp(
            swaps[hashLock].assetName,
            address(this),
            block.timestamp,
            hashLock,
            receiver,
            sender,
            premiums[hashLock].expected,
            premiums[hashLock].current,
            escrows[hashLock].expected,
            escrows[hashLock].current,
            DELTA,
            startTime
        );
    }

    /**
    In order for this function to go through, Alice must approve this contract to transfer on his behalf.
    See ERC20's increaseAllowance(address spender, uint256 addedValue) documentation at 
    https://docs.openzeppelin.com/contracts/2.x/api/token/erc20 
     */
     function depositPremium(bytes32 hashLock)
    public
    payable
    canDepositPremium(hashLock)
    {
        ERC20(swaps[hashLock].assetName).transferFrom(swaps[hashLock].receiver, address(this), premiums[hashLock].expected);
        premiums[hashLock].current = premiums[hashLock].expected;
        swaps[hashLock].stepsTaken[0] = true;

        emit PremiumDeposited(
            block.timestamp,
            msg.sender,
            premiums[hashLock].expected,
            swaps[hashLock].receiver,
            address(this),
            premiums[hashLock].current,
            escrows[hashLock].current
        );
    }

    /**
    In order for this function to go through, Alice must approve this contract to transfer on her behalf.
    See ERC20's increaseAllowance(address spender, uint256 addedValue) documentation at 
    https://docs.openzeppelin.com/contracts/2.x/api/token/erc20 
     */
    function escrowAsset(bytes32 hashLock) public payable canEscrowAsset(hashLock) {
        ERC20(swaps[hashLock].assetName).transferFrom(swaps[hashLock].sender, address(this), escrows[hashLock].expected);
        escrows[hashLock].current = escrows[hashLock].expected;
        swaps[hashLock].stepsTaken[1] = true;

        emit AssetEscrowed(
            block.timestamp,
            msg.sender,
            escrows[hashLock].expected,
            swaps[hashLock].sender,
            address(this),
            premiums[hashLock].current,
            escrows[hashLock].current
        );
    }

    /**
    redeemAsset redeems the asset for the new owner and refunds the owner's premium, if it exists.
     */
    function redeemAsset(bytes32 preimage, bytes32 hashLock) public canRedeemAsset(preimage, hashLock) {
        // redeem the asset
        ERC20(swaps[hashLock].assetName).transfer(swaps[hashLock].receiver, escrows[hashLock].current);
        swaps[hashLock].stepsTaken[2] = true;
        escrows[hashLock].current = 0;

        emit AssetRedeemed(
            block.timestamp,
            msg.sender,
            escrows[hashLock].expected,
            address(this),
            swaps[hashLock].receiver,
            premiums[hashLock].current,
            escrows[hashLock].current
        );
        refundPremium(hashLock);

    }

    /**
    refundAsset both refunds the asset to its original owner and redeems the counterparty's premium.
     */
    function refundAsset(bytes32 hashLock) private canRefundAsset(hashLock) {
        // refund the asset
        ERC20(swaps[hashLock].assetName).transfer(swaps[hashLock].sender, escrows[hashLock].current);
        escrows[hashLock].current = 0;
        emit AssetRefunded(
            block.timestamp,
            msg.sender,
            escrows[hashLock].expected,
            address(this),
            swaps[hashLock].sender,
            premiums[hashLock].current,
            escrows[hashLock].current
        );

    }
    function redeemPremium(bytes32 hashLock) private canRedeemPremium(hashLock){
        ERC20(swaps[hashLock].assetName).transfer(swaps[hashLock].sender, premiums[hashLock].current);
        premiums[hashLock].current = 0;
        emit PremiumRedeemed(
            block.timestamp,
            msg.sender,
            premiums[hashLock].expected,
            address(this),
            swaps[hashLock].receiver,
            premiums[hashLock].current,
            escrows[hashLock].current
        );

    }

    /**
    This function will only be called  if Alice fails to escrow her asset or Bob redeems. 
     */
    function refundPremium(bytes32 hashLock) private canRefundPremium(hashLock){
        ERC20(swaps[hashLock].assetName).transfer(swaps[hashLock].receiver, premiums[hashLock].current);
        premiums[hashLock].current = 0;
        emit PremiumRefunded(
            block.timestamp,
            msg.sender,
            premiums[hashLock].expected,
            address(this),
            swaps[hashLock].sender,
            premiums[hashLock].current,
            escrows[hashLock].current
        );
    }
    function settleAllAssets(bytes32 hashLock) public payable canSettleAllAssets(hashLock){
        if (swaps[hashLock].stepsTaken[0] && !swaps[hashLock].stepsTaken[1])
        {
            refundPremium(hashLock);
        }
        if (swaps[hashLock].stepsTaken[0] && swaps[hashLock].stepsTaken[1] && !swaps[hashLock].stepsTaken[2])
        {
            refundAsset(hashLock);
            redeemPremium(hashLock);
        } 
        emit AllAssetsSettled(
            block.timestamp,
            swaps[hashLock].assetName,            
            premiums[hashLock].current,
            escrows[hashLock].current
            );
    }
}