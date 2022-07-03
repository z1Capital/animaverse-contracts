require("dotenv").config()
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require('@openzeppelin/hardhat-upgrades');


const fs = require('fs');
const privateKeys = fs.readFileSync(".secret").toString().trim().split('\n');
const etherscanApi = process.env.ETHSCAN_KEY ?? "";
const infuraApi = process.env.INFURA_KEY ?? "";

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${infuraApi}`,
      chainId: 1,
      accounts: privateKeys
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${infuraApi}`,
      chainId: 4,
      accounts: privateKeys
    }
  },
  etherscan: {
    apiKey: {
      rinkeby: etherscanApi,
      mainnet: etherscanApi
    }
  },
  solidity: {
    version: "0.8.15",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 20000
  }
}
