const ApricotSwap = artifacts.require("TwoPartySwapApricot");

module.exports = function (deployer) {
  deployer.deploy(ApricotSwap);
};