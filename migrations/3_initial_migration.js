var tcr = artifacts.require("Tcr");
var token = artifacts.require("Token");

module.exports = function(deployer) {
  deployer.deploy(tcr, "Worst people", "Guild of Worst people ever, only worst people allowed here!", "0x15A493e00A58e42CeB27F22119cc1Dc7c87A2321", [100, 60, 60]); // token.address
  // deployer.deploy(tcr, "DemoTcr", "0x81b799Fd5e681B788844d71c26e85Aab41e609D4", [100, 60, 60]); // new solidity
  // deployer.deploy(tcr, "BestGuildsTesters", "0x00Bfb053c776AD912FE3aA3Cc051C2488CD51a77", [100, 259200, 259200]);
};
