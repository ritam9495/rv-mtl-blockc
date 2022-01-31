const BananaSwap = artifacts.require("BananaSwap");

module.exports = function (deployer) {
  deployer.deploy(BananaSwap);
};