/**
 * @file  lib/foundry-artifact.ts
 * @notice Loads a Foundry build artifact from `out/<ContractPath>/<ContractName>.json`
 *         and returns the `bytecode` and `abi` fields needed for deployment.
 *
 *         Foundry emits the same JSON shape as Hardhat's artifacts, but the
 *         `bytecode` field is `object` (`{ object: "0x..." }`) and the ABI is
 *         in `abi` (same as Hardhat). This helper normalizes both.
 */

import * as fs from "fs";
import * as path from "path";

export interface FoundryArtifact {
    abi: readonly any[];
    bytecode: `0x${string}`;
}

export interface LoadArtifactOptions {
    /** Path to the JSON file, e.g. "../out/OnchainSVG.sol/OnchainSVG.json" */
    path?: string;
    /** Contract name (used to derive the default path) */
    name?: string;
}

/**
 * Default artifact path. Resolved relative to the agent/ working dir.
 * Override with the `FORGE_ARTIFACT_PATH` env var or the `path` option.
 */
export function defaultArtifactPath(name = "OnchainSVG"): string {
    if (process.env.FORGE_ARTIFACT_PATH) return process.env.FORGE_ARTIFACT_PATH;
    return path.resolve(__dirname, "..", "..", "..", "out", `OnchainSVG.sol`, `${name}.json`);
}

/**
 * Load a Foundry build artifact and return its `bytecode` + `abi`.
 * Throws with a clear message if the file is missing — the user probably
 * hasn't run `forge build` yet.
 */
export function loadFoundryArtifact(opts: LoadArtifactOptions = {}): FoundryArtifact {
    const file = opts.path ?? defaultArtifactPath(opts.name);
    if (!fs.existsSync(file)) {
        throw new Error(
            `Foundry artifact not found at ${file}.\n` +
                `Run \`forge build\` from the project root first, or set FORGE_ARTIFACT_PATH.\n` +
                `Expected: out/OnchainSVG.sol/OnchainSVG.json (after \`forge build\`).`,
        );
    }
    const raw = fs.readFileSync(file, "utf-8");
    const parsed = JSON.parse(raw);

    // Foundry bytecode is `{ object: "0x..." }`; some older versions may emit
    // a plain string. Handle both.
    let bytecode: `0x${string}`;
    if (typeof parsed.bytecode === "string") {
        bytecode = parsed.bytecode as `0x${string}`;
    } else if (parsed.bytecode && typeof parsed.bytecode.object === "string") {
        bytecode = parsed.bytecode.object as `0x${string}`;
    } else {
        throw new Error(`Artifact at ${file} has no bytecode field`);
    }

    if (!bytecode.startsWith("0x") || bytecode.length < 4) {
        throw new Error(`Bytecode in ${file} looks empty: ${bytecode.slice(0, 16)}...`);
    }

    if (!Array.isArray(parsed.abi)) {
        throw new Error(`Artifact at ${file} has no abi field`);
    }

    return { abi: parsed.abi, bytecode };
}
