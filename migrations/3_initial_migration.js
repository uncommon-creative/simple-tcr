var tcr = artifacts.require("Tcr");
var token = artifacts.require("Token");

module.exports = function(deployer) {
  deployer.deploy(tcr, "Best of legal / tech advisors (Italia)", "Best of legal / tech advisors (Italia)", "0x568adfa602e8ba1bef461d7b7776179ee810257e", [100, 600, 600]); // token.address
  // deployer.deploy(tcr, "DemoTcr", "0x81b799Fd5e681B788844d71c26e85Aab41e609D4", [100, 60, 60]); // new solidity
  // deployer.deploy(tcr, "BestGuildsTesters", "0x00Bfb053c776AD912FE3aA3Cc051C2488CD51a77", [100, 259200, 259200]);
};
