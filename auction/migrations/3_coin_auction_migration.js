const CoinAuction = artifacts.require("CoinAuction");

module.exports = function(deployer) {
  deployer.deploy(CoinAuction);
};
