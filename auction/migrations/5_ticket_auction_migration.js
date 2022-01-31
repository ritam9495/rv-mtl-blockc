const TicketAuction = artifacts.require("TicketAuction");

module.exports = function(deployer) {
  deployer.deploy(TicketAuction);
};
