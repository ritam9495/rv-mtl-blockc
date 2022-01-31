const Ticket = artifacts.require("Ticket");

module.exports = function(deployer) {
  deployer.deploy(Ticket, 'Ticket', 'TCK');
};
