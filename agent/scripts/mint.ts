import { PublicClient, WalletClient, encodeFunctionData, parseAbi } from "viem";
import { explorerTxUrl, PharosNetwork, getClients } from "./lib/pharos";
import { validateSVG } from "./validate-svg";
import type { MintResult } from "./lib/types";

const ONCHAIN_SVG_ABI = parseAbi([
    "function mint(address to, string svg) external returns (uint256)",
    "function mintWithMetadata(address to, string svg, string name, string description) external returns (uint256)",
    "function mintBatch(address to, string svg, uint256 count) external returns (uint256 fromTokenId, uint256 toTokenId)",
    "function mintBatchDistinct(address[] recipients, string[] svgs) external returns (uint256 fromTokenId, uint256 toTokenId)",
    "function totalSupply() external view returns (uint256)",
    "function owner() external view returns (address)",
    "function MAX_BATCH_SIZE() external pure returns (uint256)",
    "event Minted(address indexed to, uint256 indexed tokenId, string svgHash)",
    "event BatchMinted(address indexed to, uint256 fromTokenId, uint256 toTokenId)",
]);

export const MAX_BATCH_SIZE = 50;

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

export interface BatchMintOptions {
    publicClient: PublicClient;
    walletClient: WalletClient;
    account: `0x${string}`;
    collection: `0x${string}`;
    to: `0x${string}`;
    svg: string;
    count: number;
    network: PharosNetwork;
}

export interface BatchMintDistinctOptions {
    publicClient: PublicClient;
    walletClient: WalletClient;
    account: `0x${string}`;
    collection: `0x${string}`;
    recipients: `0x${string}`[];
    svgs: string[];
    network: PharosNetwork;
}

export interface BatchMintResult {
    txHash: `0x${string}`;
    fromTokenId: string;
    toTokenId: string;
    collection: `0x${string}`;
    to?: `0x${string}`;
    explorerUrl: string;
}

async function ownerGuard(opts: {
    publicClient: PublicClient;
    collection: `0x${string}`;
    account: `0x${string}`;
}): Promise<void> {
    const owner = (await opts.publicClient.readContract({
        address: opts.collection,
        abi: ONCHAIN_SVG_ABI,
        functionName: "owner",
    })) as `0x${string}`;
    if (owner.toLowerCase() !== opts.account.toLowerCase()) {
        throw new Error(
            `Account ${opts.account} does not own collection ${opts.collection} (owner=${owner})`,
        );
    }
}

export async function mintSVG(opts: MintOptions): Promise<MintResult> {
    const validation = validateSVG(opts.svg);
    if (!validation.ok) {
        throw new Error(`Invalid SVG: ${validation.errors.join("; ")}`);
    }
    await ownerGuard({ publicClient: opts.publicClient, collection: opts.collection, account: opts.account });

    const hasMetadata = !!(opts.name && opts.description);
    const data = encodeFunctionData({
        abi: ONCHAIN_SVG_ABI,
        functionName: hasMetadata ? "mintWithMetadata" : "mint",
        args: hasMetadata ? [opts.to, opts.svg, opts.name!, opts.description!] : [opts.to, opts.svg],
    });

    const txHash = await opts.walletClient.sendTransaction({
        account: opts.account,
        chain: opts.walletClient.chain ?? undefined,
        to: opts.collection,
        data,
    } as any);

    const receipt = await opts.publicClient.waitForTransactionReceipt({ hash: txHash });
    const log = receipt.logs.find((l) => l.address.toLowerCase() === opts.collection.toLowerCase());
    let tokenId = "0";
    if (log && log.topics[3]) {
        tokenId = BigInt(log.topics[3]).toString();
    } else {
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

/**
 * Mint `count` tokens to `to`, all sharing the same `svg`.
 * Capped at MAX_BATCH_SIZE = 50 (on-chain enforced).
 */
export async function mintBatchSVG(opts: BatchMintOptions): Promise<BatchMintResult> {
    if (opts.count <= 0) throw new Error(`count must be > 0, got ${opts.count}`);
    if (opts.count > MAX_BATCH_SIZE) {
        throw new Error(`count ${opts.count} exceeds MAX_BATCH_SIZE=${MAX_BATCH_SIZE}`);
    }
    const validation = validateSVG(opts.svg);
    if (!validation.ok) {
        throw new Error(`Invalid SVG: ${validation.errors.join("; ")}`);
    }
    await ownerGuard({ publicClient: opts.publicClient, collection: opts.collection, account: opts.account });

    const data = encodeFunctionData({
        abi: ONCHAIN_SVG_ABI,
        functionName: "mintBatch",
        args: [opts.to, opts.svg, BigInt(opts.count)],
    });

    const txHash = await opts.walletClient.sendTransaction({
        account: opts.account,
        chain: opts.walletClient.chain ?? undefined,
        to: opts.collection,
        data,
    } as any);

    const receipt = await opts.publicClient.waitForTransactionReceipt({ hash: txHash });

    // Parse BatchMinted event topics:
    // BatchMinted(address indexed to, uint256 indexed fromTokenId, uint256 indexed toTokenId)
    // topics[0] = event sig, topics[1] = to, topics[2] = fromTokenId, topics[3] = toTokenId
    const batchLog = receipt.logs.find((l) => l.address.toLowerCase() === opts.collection.toLowerCase());
    let fromTokenId = "0";
    let toTokenId = "0";
    if (batchLog && batchLog.topics.length >= 4) {
        fromTokenId = BigInt(batchLog.topics[2]!).toString();
        toTokenId = BigInt(batchLog.topics[3]!).toString();
    } else {
        // Fallback: compute from totalSupply
        const total = (await opts.publicClient.readContract({
            address: opts.collection,
            abi: ONCHAIN_SVG_ABI,
            functionName: "totalSupply",
        })) as bigint;
        toTokenId = total.toString();
        fromTokenId = (total - BigInt(opts.count) + 1n).toString();
    }

    return {
        txHash,
        fromTokenId,
        toTokenId,
        collection: opts.collection,
        to: opts.to,
        explorerUrl: explorerTxUrl(txHash, opts.network),
    };
}

/**
 * Mint one token per (recipient, svg) pair, atomically.
 * If any single item is bad, the whole batch reverts.
 */
export async function mintBatchDistinctSVG(
    opts: BatchMintDistinctOptions,
): Promise<BatchMintResult> {
    if (opts.recipients.length === 0) throw new Error("recipients must be non-empty");
    if (opts.recipients.length !== opts.svgs.length) {
        throw new Error(
            `recipients.length (${opts.recipients.length}) != svgs.length (${opts.svgs.length})`,
        );
    }
    if (opts.recipients.length > MAX_BATCH_SIZE) {
        throw new Error(
            `batch size ${opts.recipients.length} exceeds MAX_BATCH_SIZE=${MAX_BATCH_SIZE}`,
        );
    }
    // Validate every SVG up front (the on-chain check is defense in depth).
    for (let i = 0; i < opts.svgs.length; i++) {
        const v = validateSVG(opts.svgs[i]);
        if (!v.ok) {
            throw new Error(`Invalid SVG at index ${i}: ${v.errors.join("; ")}`);
        }
    }
    await ownerGuard({ publicClient: opts.publicClient, collection: opts.collection, account: opts.account });

    const data = encodeFunctionData({
        abi: ONCHAIN_SVG_ABI,
        functionName: "mintBatchDistinct",
        args: [opts.recipients, opts.svgs],
    });

    const txHash = await opts.walletClient.sendTransaction({
        account: opts.account,
        chain: opts.walletClient.chain ?? undefined,
        to: opts.collection,
        data,
    } as any);

    const receipt = await opts.publicClient.waitForTransactionReceipt({ hash: txHash });
    const batchLog = receipt.logs.find((l) => l.address.toLowerCase() === opts.collection.toLowerCase());
    let fromTokenId = "0";
    let toTokenId = "0";
    if (batchLog && batchLog.topics.length >= 4) {
        fromTokenId = BigInt(batchLog.topics[2]!).toString();
        toTokenId = BigInt(batchLog.topics[3]!).toString();
    } else {
        const total = (await opts.publicClient.readContract({
            address: opts.collection,
            abi: ONCHAIN_SVG_ABI,
            functionName: "totalSupply",
        })) as bigint;
        toTokenId = total.toString();
        fromTokenId = (total - BigInt(opts.recipients.length) + 1n).toString();
    }

    return {
        txHash,
        fromTokenId,
        toTokenId,
        collection: opts.collection,
        explorerUrl: explorerTxUrl(txHash, opts.network),
    };
}

// CLI
if (require.main === module) {
    const args = parseArgs(process.argv.slice(2));
    if (!args.collection || !args.to) {
        console.error(
            "usage: mint --collection 0x... --to 0x... --svg-file <path> [--name <n> --description <d>] [--network mainnet|testnet]\n" +
            "       mint --collection 0x... --to 0x... --svg-file <path> --count <N>\n" +
            "       mint --collection 0x... --recipients-file <csv> --svgs-file <csv>",
        );
        process.exit(2);
    }

    const network = (args.network as PharosNetwork) ?? "mainnet";
    const { publicClient, walletClient, account } = getClients(network);

    (async () => {
        const fs = require("fs");

        if (args["recipients-file"] && args["svgs-file"]) {
            const recipients = parseCsv(fs.readFileSync(args["recipients-file"], "utf-8"));
            const svgs = parseSvgCsv(fs.readFileSync(args["svgs-file"], "utf-8"));
            const r = await mintBatchDistinctSVG({
                publicClient,
                walletClient,
                account: account.address,
                collection: args.collection as `0x${string}`,
                recipients: recipients as `0x${string}`[],
                svgs,
                network,
            });
            console.log(JSON.stringify(r, null, 2));
            return;
        }

        const svg = args["svg-file"]
            ? fs.readFileSync(args["svg-file"], "utf-8")
            : (() => {
                  throw new Error("provide --svg-file");
              })();

        if (args.count) {
            const r = await mintBatchSVG({
                publicClient,
                walletClient,
                account: account.address,
                collection: args.collection as `0x${string}`,
                to: (args.to as `0x${string}` | undefined) ?? account.address,
                svg,
                count: Number(args.count),
                network,
            });
            console.log(JSON.stringify(r, null, 2));
            return;
        }

        const r = await mintSVG({
            publicClient,
            walletClient,
            account: account.address,
            collection: args.collection as `0x${string}`,
            to: (args.to as `0x${string}` | undefined) ?? account.address,
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

function parseCsv(text: string): string[] {
    return text
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter((line) => line.length > 0 && !line.startsWith("#"));
}

function parseSvgCsv(text: string): string[] {
    // Each line is a complete SVG (since SVGs can contain commas)
    return text
        .split(/\r?\n__SVG_BREAK__\r?\n/)
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
}
