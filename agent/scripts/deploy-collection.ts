import { getClients, explorerTxUrl, PharosNetwork } from "./lib/pharos";
import { parseAbi, encodeDeployData } from "viem";

/**
 * Deploy a new OnchainSVG collection to Pharos.
 *
 * This script uses viem's `sendTransaction` with the pre-encoded
 * `createContract` bytecode, so it does not require Hardhat at runtime.
 */
export async function deployCollection(opts: {
  name: string;
  symbol: string;
  owner?: `0x${string}`;
  network?: PharosNetwork;
  bytecode: `0x${string}`;
  abi: readonly any[];
}): Promise<{ address: `0x${string}`; txHash: `0x${string}`; explorerUrl: string; network: PharosNetwork }> {
  const network = opts.network ?? "mainnet";
  const { publicClient, walletClient, account } = getClients(network);
  const owner = opts.owner ?? account.address;

  const data = encodeDeployData({
    abi: opts.abi,
    bytecode: opts.bytecode,
    args: [opts.name, opts.symbol, owner],
  });
  if (!data) throw new Error("failed to encode deployment data");

  const txHash = await walletClient.sendTransaction({
    account,
    chain: walletClient.chain ?? undefined,
    data,
  } as any);

  const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });
  if (!receipt.contractAddress) throw new Error("deployment failed: no contract address in receipt");
  return {
    address: receipt.contractAddress,
    txHash,
    explorerUrl: explorerTxUrl(txHash, network),
    network,
  };
}

// CLI
if (require.main === module) {
  const args = parseArgs(process.argv.slice(2));
  if (!args.name || !args.symbol) {
    console.error("usage: deploy-collection --name <name> --symbol <sym> [--owner 0x...] [--network mainnet|testnet] --bytecode 0x... --abi-file <path>");
    process.exit(2);
  }
  const fs = require("fs");
  const bytecode = (args.bytecode as `0x${string}`);
  const abi = JSON.parse(fs.readFileSync(args["abi-file"], "utf-8"));
  deployCollection({
    name: args.name!,
    symbol: args.symbol!,
    owner: args.owner as `0x${string}` | undefined,
    network: (args.network as PharosNetwork) ?? "mainnet",
    bytecode,
    abi,
  })
    .then((r) => {
      console.log(JSON.stringify(r, null, 2));
    })
    .catch((e) => {
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
