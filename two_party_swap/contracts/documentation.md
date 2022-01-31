# Documentation

## `Apricot.sol`
---
This file contains the Apricot contract, which is our implementation of an ERC20 token. Click [here](https://medium.com/@eiki1212/what-is-erc-20-explanation-of-details-eacf9f288f8b) for more information on ERC20 tokens.

## `ApricotSwap.sol`
---
This file contains the TwoPartySwapApricot contract, which is one side of a 2-party swap. 

**What's an `event`?** An event is essentially a logging statement. Functions emit events

**What's a `modifier`?** We use modifiers to automatically check that conditions are satisfied before funning a function. Think of it as an assert statement run prior to the function. If the assert fails, the function doesn't run.

> **Note:** If any of the keywords in the file are still confusing, please check out Solidity's brief [syntax documentation](https://docs.soliditylang.org/en/v0.8.7/structure-of-a-contract.html)

### Relevant Methods:
I've elided parameters, as to not overwhelm this documentation
- setup(): called by either person of the swap to set up the contract. 
- depositPremium(): called by the seeker of the asset to deposit their premium.
- escrowAsset(): called by the original asset owner to escrow their asset.  
- redeemAsset(): called by the seeker to redeem the asset they're swapping for. This can only be called if the protocol succeeds.
- refundAsset(): called by the original owner of the asset if the contract falls through. This allows them to get their asset back.
- redeemPremium(): called by the original owner of the asset if the contract falls through. This allows them to receive the premium for locking up their asset on the chain.

## `Banana.sol`
---
This file contains the Banana contract, which is our implementation of an ERC20 token. Click [here](https://medium.com/@eiki1212/what-is-erc-20-explanation-of-details-eacf9f288f8b) for more information on ERC20 tokens.

## `BananaSwap.sol`
---
This file contains the TwoPartySwapBanana contract, which is the other side of a 2-party swap. It is functionally idential to `ApricotSwap.sol`, with Alice and Bobs' roles reversed.

> See `ApricotSwap.sol` header above for relevant methods