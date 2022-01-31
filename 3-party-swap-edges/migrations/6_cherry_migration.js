const Cherry = artifacts.require("Cherry");

module.exports = function (deployer) {
  deployer.deploy(Cherry, 'Cherry', 'CHE');
};