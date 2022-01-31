const CherrySwap = artifacts.require("CherrySwap");

module.exports = function (deployer) {
  deployer.deploy(CherrySwap);
};