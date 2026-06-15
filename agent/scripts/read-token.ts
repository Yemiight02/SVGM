import { parseAbi, createPublicClient, http } from "viem";
import { resolveChain, PharosNetwork } from "./lib/pharos";

const ONCHAIN_SVG_ABI = parseAbi([
    "function ownerOf(uint256 tokenId) external view returns (address)",
    "function tokenURI(uint256 tokenId) external view returns (string)",
    "function totalSupply() external view returns (uint256)",
]);

export interface ReadTokenResult {
    collection: `0x${string}`;
    tokenId: string;
    owner: `0x${string}`;
    tokenURI: string;
    metadataJson?: any;
    imageDataUri?: string;
}

export async function readToken(opts: {
    collection: `0x${string}`;
    tokenId: bigint | string | number;
    network?: PharosNetwork;
}): Promise<ReadTokenResult> {
    const network = opts.network ?? "mainnet";
    const chain = resolveChain(network);
    const client = createPublicClient({ chain, transport: http(chain.rpcUrls.default.http[0]) });

    const owner = (await client.readContract({
        address: opts.collection,
        abi: ONCHAIN_SVG_ABI,
        functionName: "ownerOf",
        args: [BigInt(opts.tokenId)],
    })) as `0x${string}`;

    const tokenURI = (await client.readContract({
        address: opts.collection,
        abi: ONCHAIN_SVG_ABI,
        functionName: "tokenURI",
        args: [BigInt(opts.tokenId)],
    })) as string;

    const result: ReadTokenResult = {
        collection: opts.collection,
        tokenId: BigInt(opts.tokenId).toString(),
        owner,
        tokenURI,
    };

    if (tokenURI.startsWith("data:application/json;base64,")) {
        const b64 = tokenURI.slice("data:application/json;base64,".length);
        const json = JSON.parse(Buffer.from(b64, "base64").toString("utf-8"));
        result.metadataJson = json;
        if (
            json.image &&
            typeof json.image === "string" &&
            json.image.startsWith("data:image/svg+xml;base64,")
        ) {
            const svgB64 = json.image.slice("data:image/svg+xml;base64,".length);
            result.imageDataUri = `data:image/svg+xml;base64,${svgB64}`;
        }
    }
    return result;
}

if (require.main === module) {
    const args = parseArgs(process.argv.slice(2));
    if (!args.collection || args["token-id"] === undefined) {
        console.error("usage: read-token --collection 0x... --token-id <n> [--network mainnet|testnet]");
        process.exit(2);
    }
    readToken({
        collection: args.collection as `0x${string}`,
        tokenId: args["token-id"]!,
        network: (args.network as PharosNetwork) ?? "mainnet",
    })
        .then((r) => console.log(JSON.stringify(r, null, 2)))
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
