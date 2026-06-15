import { getClients, explorerTxUrl, PharosNetwork } from "./lib/pharos";
import { loadFoundryArtifact } from "./lib/foundry-artifact";
import { parseAbi, encodeDeployData } from "viem";

/**
 * Deploy a new OnchainSVG collection to Pharos.
 *
 * This script reads the Foundry build artifact at `out/OnchainSVG.sol/OnchainSVG.json`
 * and uses viem's `sendTransaction` with the encoded `createContract` bytecode
 * — no Hardhat, no deployment plugin, just viem + forge build.
 *
 * Prereq: `forge build` (from the project root) must have produced the artifact.
 */
export async function deployCollection(opts: {
    name: string;
    symbol: string;
    owner?: `0x${string}`;
    network?: PharosNetwork;
}): Promise<{ address: `0x${string}`; txHash: `0x${string}`; explorerUrl: string; network: PharosNetwork }> {
    const network = opts.network ?? "mainnet";
    const { publicClient, walletClient, account } = getClients(network);
    const owner = opts.owner ?? account.address;

    // Load bytecode + ABI from `out/OnchainSVG.sol/OnchainSVG.json` (Foundry).
    const { abi, bytecode } = loadFoundryArtifact({ name: "OnchainSVG" });

    const data = encodeDeployData({
        abi: abi as any,
        bytecode,
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
        console.error("usage: deploy-collection --name <name> --symbol <sym> [--owner 0x...] [--network mainnet|testnet]");
        process.exit(2);
    }
    deployCollection({
        name: args.name!,
        symbol: args.symbol!,
        owner: args.owner as `0x${string}` | undefined,
        network: (args.network as PharosNetwork) ?? "mainnet",
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
