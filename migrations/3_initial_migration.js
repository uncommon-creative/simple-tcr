var tcr = artifacts.require("Tcr");
var token = artifacts.require("Token");

module.exports = function(deployer) {
  deployer.deploy(tcr, "DemoTcr", "0x434E80DB12dABbCFa0f4e1742AF5ACf5c6978bE1", [100, 60, 60]);
  // deployer.deploy(tcr, "BestGuildsTesters", "0x00Bfb053c776AD912FE3aA3Cc051C2488CD51a77", [100, 259200, 259200]);
};
