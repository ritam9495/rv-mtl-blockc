const ApricotSwap = artifacts.require("ApricotSwap");

module.exports = function (deployer) {
  deployer.deploy(ApricotSwap);
};