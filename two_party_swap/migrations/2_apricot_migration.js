const Apricot = artifacts.require("Apricot");

module.exports = function (deployer) {
  deployer.deploy(Apricot, 'Apricot', 'APR');
};