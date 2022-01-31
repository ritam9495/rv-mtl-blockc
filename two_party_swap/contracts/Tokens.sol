// This contract was based

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./libraries/token/ERC20/ERC20.sol";

contract Tokens {

  /**
    Wrapper for ERC20 Token
   */
  struct Token {
        bytes32 ticker;
        address tokenAddress;
    }

  mapping(bytes32 => Token) public tokens;
  mapping(address => mapping(bytes32 => uint)) public traderBalances;

  modifier tokenExists(bytes32 ticker) {
        require(
            tokens[ticker].tokenAddress != address(0),
            'this token does not exist'
        );
        _;
    }

  function addToken(
        bytes32 ticker,
        address tokenAddress)
        external {
        tokens[ticker] = Token(ticker, tokenAddress);
    }

  function deposit(
      uint256 amount,
      bytes32 ticker)
      tokenExists(ticker)
      external {
      IERC20(tokens[ticker].tokenAddress).transferFrom(
          msg.sender,
          address(this),
          amount
      );
      traderBalances[msg.sender][ticker] += amount;
  }
}

