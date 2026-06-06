import { defineChain } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { createPublicClient, createWalletClient, http, PublicClient, WalletClient } from "viem";

/**
 * Pharos Network — mainnet (primary)
 */
export const pharosMainnet = defineChain({
  id: 1672,
  name: "Pharos Mainnet",
  nativeCurrency: { name: "PharosCoin", symbol: "PROS", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://rpc.pharos.xyz"] },
    public: { http: ["https://rpc.pharos.xyz"] },
  },
  blockExplorers: {
    default: { name: "Pharos Explorer", url: "https://pharosscan.xyz" },
  },
  testnet: false,
});

/**
 * Pharos Atlantic — testnet (additional)
 */
export const pharosTestnet = defineChain({
  id: 688688,
  name: "Pharos Atlantic Testnet",
  nativeCurrency: { name: "PharosCoin", symbol: "PROS", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://atlantic.dplabs-internal.com"] },
    public: { http: ["https://atlantic.dplabs-internal.com"] },
  },
  blockExplorers: {
    default: { name: "Pharos Testnet Explorer", url: "https://testnet.pharosscan.xyz" },
  },
  testnet: true,
});

export type PharosNetwork = "mainnet" | "testnet";

export function resolveChain(network: PharosNetwork = "mainnet") {
  return network === "mainnet" ? pharosMainnet : pharosTestnet;
}

export function explorerTxUrl(hash: `0x${string}`, network: PharosNetwork = "mainnet"): string {
  const base = network === "mainnet" ? "https://pharosscan.xyz" : "https://testnet.pharosscan.xyz";
  return `${base}/tx/${hash}`;
}

export interface PharosClients {
  publicClient: PublicClient;
  walletClient: WalletClient;
  account: ReturnType<typeof privateKeyToAccount>;
  network: PharosNetwork;
  chain: ReturnType<typeof resolveChain>;
}

export function getClients(network: PharosNetwork = "mainnet"): PharosClients {
  const pk = process.env.PRIVATE_KEY;
  if (!pk) throw new Error("PRIVATE_KEY is required");
  const normalized = (pk.startsWith("0x") ? pk : `0x${pk}`) as `0x${string}`;
  const account = privateKeyToAccount(normalized);
  const chain = resolveChain(network);
  const rpc = process.env.PHAROS_RPC_URL || chain.rpcUrls.default.http[0];

  const publicClient = createPublicClient({ chain, transport: http(rpc) });
  const walletClient = createWalletClient({ chain, transport: http(rpc), account });
  return { publicClient, walletClient, account, network, chain };
}
