const Banana = artifacts.require("Banana");

module.exports = function (deployer) {
  deployer.deploy(Banana, 'Banana', 'BAN');
};