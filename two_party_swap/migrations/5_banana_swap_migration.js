const BananaSwap = artifacts.require("TwoPartySwapBanana");

module.exports = function (deployer) {
  deployer.deploy(BananaSwap);
};