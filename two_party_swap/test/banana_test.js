const { assert } = require("chai");
const chai = require("chai");
// Enable and inject BN dependency
chai.use(require("chai-bignumber")());

const Banana = artifacts.require("Banana");

contract("BananaSwap", async (accounts) => {
  /*
    This test checks that one trader can transfer to another
  */
  it("Banana", async () => {
    const ban = await Banana.deployed();

    const account_one = accounts[0];
    const account_two = accounts[1];

    //starting state
    const total_supply = await ban.totalSupply();
    const start_balance = await ban.balanceOf(account_one);

    // check that 1st account has all of supply
    assert.equal(total_supply.toNumber(), start_balance.toNumber(), "balance of trader 1 is not equal to total supply.")

    //transfer money over
    await ban.transfer(account_two, 10, { from: account_one });
    const balance_1 = await ban.balanceOf(account_one);
    const balance_2 = await ban.balanceOf(account_two);

    // check that balances updated
    assert.equal(balance_1.toNumber(), start_balance.toNumber() - 10, "balance of trader 1 was not updated.")
    assert.equal(balance_2.toNumber(), 10, "balance of trader 2 was not updated. balance_2: " + balance_2);
  });
});