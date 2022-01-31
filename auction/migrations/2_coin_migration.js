const Coin = artifacts.require("Coin");

module.exports = function(deployer) {
  deployer.deploy(Coin, 'Coin', 'COI');
};
