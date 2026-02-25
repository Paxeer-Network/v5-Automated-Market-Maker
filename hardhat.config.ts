import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-contract-sizer";
import "dotenv/config";

const privateKey = process.env.PRIVATE_KEY;

if (!privateKey) {
  console.warn("WARNING: PRIVATE_KEY is not set in the .env file. Deployments will not be possible.");
}

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.27",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  networks: {
    hardhat: {
      chainId: 125,
    },
    "paxeer-network": {
      url: "https://public-rpc.paxeer.app/rpc",
      accounts: privateKey ? [privateKey] : [],
      chainId: 125,
    },
  },
  etherscan: {
    apiKey: {
      "paxeer-network": "empty",
    },
    customChains: [
      {
        network: "paxeer-network",
        chainId: 125,
        urls: {
          apiURL: "https://paxscan.paxeer.app/api",
          browserURL: "https://paxscan.paxeer.app",
        },
      },
    ],
  },
  paths: {
    sources: "./src",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

export default config;