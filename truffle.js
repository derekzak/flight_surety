const HDWalletProvider = require("@truffle/hdwallet-provider");
const mnemonic = "ring treat cinnamon spin mule income crunch about balcony blouse collect unlock";

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/", 0, 50, true, "m/44'/60'/0'/0/");
      },
      network_id: '*'
    }
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};