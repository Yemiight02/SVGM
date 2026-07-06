/**
 * No-op IPFS helper kept for parity with NFT tooling that conventionally
 * has an `ipfs` module. SVGM stores everything onchain; this file is here
 * so downstream tools (and agents) that import a path like
 * `agent/scripts/lib/ipfs` don't break.
 */
export function uploadToIPFS(_data: string | Uint8Array): Promise<{ cid: string; uri: string }> {
    return Promise.resolve({ cid: "onchain", uri: "data:application/octet-stream;base64," });
}
