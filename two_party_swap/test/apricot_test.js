const { assert } = require("chai");
const chai = require("chai");
// Enable and inject BN dependency
chai.use(require("chai-bignumber")());

const Apricot = artifacts.require("Apricot");

contract("ApricotSwap", async (accounts) => {
  /*
    This test checks that one trader can transfer to another
  */
  it("Apricot", async () => {
    const apr = await Apricot.deployed();

    const account_one = accounts[0];
    const account_two = accounts[1];

    //starting state
    const total_supply = await apr.totalSupply();
    const start_balance = await apr.balanceOf(account_one);

    // check that 1st account has all of supply
    assert.equal(total_supply.toNumber(), start_balance.toNumber(), "balance of trader 1 is not equal to total supply.")

    //transfer money over
    await apr.transfer(account_two, 10, { from: account_one });
    const balance_1 = await apr.balanceOf(account_one);
    const balance_2 = await apr.balanceOf(account_two);

    // check that balances updated
    assert.equal(balance_1.toNumber(), start_balance.toNumber() - 10, "balance of trader 1 was not updated.")
    assert.equal(balance_2.toNumber(), 10, "balance of trader 2 was not updated. balance_2: " + balance_2);
  });
});

//OLD STUFF, KEEPING HERE JUST IN CASE
  // it("Transfer Between Accounts", async () => {
  //   const apr = await Apricot.deployed();
  //   const account_one = accounts[0];
  //   const account_two = accounts[1];

  //   //starting state: 1st account has all of supply
  //   const total_supply = await apr.totalSupply();
  //   const start_balance_1 = await apr.balanceOf(account_one);
  //   const start_balance_2 = await apr.balanceOf(account_two);

  //   assert.isTrue(
  //     total_supply.eq(start_balance_1),
  //     "total supply and start balance not equal"
  //   );
  //   expect(start_balance_2).to.be.a.bignumber;
  //   // assert.isTrue(start_balance_2.eq(0), "Expected start_balance_2: 0 || actual: " + start_balance_2)
  // });

//Example usages:
//  assert.isFalse(total_supply.eq(start_balance), "start_balance: " + start_balance)

//     await apr.increaseAllowance(apr.address, start_balance, {
//       from: account_one,
//     });
//     await apr.increaseAllowance(apr.address, start_balance, {
//       from: account_two,
//     });
//     await apr.approve(apr.address, start_balance, { from: account_one });
//     const allowance_1 = await apr.allowance(account_one, apr.address);
//     const allowance_2 = await apr.allowance(account_two, apr.address);
//     assert.isTrue(
//       allowance_1.eq(start_balance),
//       "allowance: " + allowance_1 + " start_balance: " + start_balance
//     );