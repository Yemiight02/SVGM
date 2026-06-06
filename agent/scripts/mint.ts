import { PublicClient, WalletClient, encodeFunctionData, parseAbi } from "viem";
import { explorerTxUrl, PharosNetwork, getClients } from "./lib/pharos";
import { validateSVG } from "./validate-svg";
import type { MintResult } from "./lib/types";

const ONCHAIN_SVG_ABI = parseAbi([
  "function mint(address to, string svg) external returns (uint256)",
  "function mintWithMetadata(address to, string svg, string name, string description) external returns (uint256)",
  "function totalSupply() external view returns (uint256)",
  "function owner() external view returns (address)",
  "event Minted(address indexed to, uint256 indexed tokenId, string svgHash)",
]);

export interface MintOptions {
  publicClient: PublicClient;
  walletClient: WalletClient;
  account: `0x${string}`;
  collection: `0x${string}`;
  to: `0x${string}`;
  svg: string;
  name?: string;
  description?: string;
  network: PharosNetwork;
}

export async function mintSVG(opts: MintOptions): Promise<MintResult> {
  const validation = validateSVG(opts.svg);
  if (!validation.ok) {
    throw new Error(`Invalid SVG: ${validation.errors.join("; ")}`);
  }

  // Verify the caller actually owns the collection (defense in depth).
  const owner = (await opts.publicClient.readContract({
    address: opts.collection,
    abi: ONCHAIN_SVG_ABI,
    functionName: "owner",
  })) as `0x${string}`;
  if (owner.toLowerCase() !== opts.account.toLowerCase()) {
    throw new Error(`Account ${opts.account} does not own collection ${opts.collection} (owner=${owner})`);
  }

  const hasMetadata = !!(opts.name && opts.description);
  const data = encodeFunctionData({
    abi: ONCHAIN_SVG_ABI,
    functionName: hasMetadata ? "mintWithMetadata" : "mint",
    args: hasMetadata
      ? [opts.to, opts.svg, opts.name!, opts.description!]
      : [opts.to, opts.svg],
  });

  const txHash = await opts.walletClient.sendTransaction({
    account: opts.account,
    chain: opts.walletClient.chain ?? undefined,
    to: opts.collection,
    data,
  } as any);

  const receipt = await opts.publicClient.waitForTransactionReceipt({ hash: txHash });
  // The Minted event is in the first log; tokenId is the second indexed topic-shifted
  // parameter (third topic when including the event sig).
  const log = receipt.logs.find((l) => l.address.toLowerCase() === opts.collection.toLowerCase());
  let tokenId = "0";
  if (log && log.topics[3]) {
    tokenId = BigInt(log.topics[3]).toString();
  } else {
    // Fallback: read totalSupply before & after.
    const total = (await opts.publicClient.readContract({
      address: opts.collection,
      abi: ONCHAIN_SVG_ABI,
      functionName: "totalSupply",
    })) as bigint;
    tokenId = total.toString();
  }

  return {
    txHash,
    tokenId,
    to: opts.to,
    collection: opts.collection,
    explorerUrl: explorerTxUrl(txHash, opts.network),
  };
}

// CLI
if (require.main === module) {
  const args = parseArgs(process.argv.slice(2));
  if (!args.collection || !args.to) {
    console.error(
      "usage: mint --collection 0x... --to 0x... [--svg-file <path> | --prompt '<json>'] [--name <n> --description <d>] [--network mainnet|testnet]",
    );
    process.exit(2);
  }
  const network = (args.network as PharosNetwork) ?? "mainnet";
  const { publicClient, walletClient, account } = getClients(network);

  (async () => {
    let svg: string;
    if (args["svg-file"]) {
      svg = require("fs").readFileSync(args["svg-file"], "utf-8");
    } else if (args.prompt) {
      const { generateSVG } = require("./generate-svg");
      svg = generateSVG(JSON.parse(args.prompt));
    } else {
      throw new Error("provide --svg-file or --prompt");
    }

    const r = await mintSVG({
      publicClient,
      walletClient,
      account: account.address,
      collection: args.collection as `0x${string}`,
      to: args.to as `0x${string}`,
      svg,
      name: args.name,
      description: args.description,
      network,
    });
    console.log(JSON.stringify(r, null, 2));
  })().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}

function parseArgs(argv: string[]): Record<string, string | undefined> {
  const out: Record<string, string | undefined> = {};
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (k.startsWith("--")) {
      const key = k.slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith("--")) {
        out[key] = next;
        i++;
      } else {
        out[key] = "true";
      }
    }
  }
  return out;
}
