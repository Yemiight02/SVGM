export interface GenerateSVGOptions {
    shapes?: Array<"circle" | "rect" | "polygon" | "line" | "path">;
    palette?: string[];
    seed?: number;
    size?: number;
    background?: string;
}

export interface ValidateSVGResult {
    ok: boolean;
    errors: string[];
    sizeBytes: number;
}

export interface MintResult {
    txHash: `0x${string}`;
    tokenId: string;
    to: `0x${string}`;
    collection: `0x${string}`;
    explorerUrl: string;
}
