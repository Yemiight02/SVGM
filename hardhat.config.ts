import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const PHAROS_RPC_URL = process.env.PHAROS_RPC_URL ?? "https://rpc.pharos.xyz";
const PHAROS_TESTNET_RPC_URL = process.env.PHAROS_TESTNET_RPC_URL ?? "https://atlantic.dplabs-internal.com";
const PRIVATE_KEY = process.env.PRIVATE_KEY ?? "0x" + "0".repeat(64);

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: { enabled: true, runs: 200 },
      viaIR: true,
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    pharos: {
      url: PHAROS_RPC_URL,
      chainId: 1672,
      accounts: [PRIVATE_KEY],
    },
    pharosTestnet: {
      url: PHAROS_TESTNET_RPC_URL,
      chainId: 688688,
      accounts: [PRIVATE_KEY],
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

export default config;
