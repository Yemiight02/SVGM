# SVGM Agent Runtime

This is the **runtime** the SVGM Service Agent exposes to Anvita Flow.
Each `.ts` file is a callable function — both as a CLI and as an
importable module.

## Files

| File                    | Purpose                                                          |
| ----------------------- | ---------------------------------------------------------------- |
| `generate-svg.ts`       | Deterministic SVG generator (mulberry32 seed → shapes+palette)   |
| `validate-svg.ts`       | XML well-formedness + safety check (rejects `<script>`, oversize)|
| `deploy-collection.ts`  | Deploy a new OnchainSVG ERC-721 to Pharos                        |
| `mint.ts`               | Mint to an existing collection (single or batch)                 |
| `read-token.ts`         | Read a token's onchain SVG and metadata                          |
| `lib/pharos.ts`         | Chain config, RPC clients, env loader                            |
| `lib/foundry-artifact.ts`| Read Foundry-compiled bytecode/ABI                              |
| `lib/types.ts`          | Shared TypeScript types                                          |
| `lib/ipfs.ts`           | No-op (kept for parity with onchain-only design)                |

## Install

```bash
npm install --no-audit --no-fund --omit=optional
```

If running on **Termux / Android**, see `../references/TERMUX.md` for
workarounds (no native build tools; we use `viem` which is JS-only).

## Use as a library

```typescript
import { generateSVG } from "./generate-svg";
import { validateSVG } from "./validate-svg";
import { mintSVG } from "./mint";
import { deployCollection } from "./deploy-collection";
import { readToken } from "./read-token";
```

All five are exported as ESM functions. They expect a Pharos RPC and a
funded `PRIVATE_KEY` (via env or explicit `account` param).

## Use as a CLI

```bash
npx ts-node ./generate-svg.ts --seed 42 --out ./art.svg
npx ts-node ./validate-svg.ts ./art.svg
npx ts-node ./deploy-collection.ts --name "Test" --symbol "TST"
npx ts-node ./mint.ts --collection 0x... --to 0x... --svg-file ./art.svg
npx ts-node ./read-token.ts --collection 0x... --token-id 1
```

## Env vars

Copy `.env.example` to `.env` and fill in:

```
PRIVATE_KEY=0x...           # hex, with or without 0x
PHAROS_RPC_URL=https://rpc.pharos.xyz
CHAIN_ID=1672               # 688688 for Atlantic testnet
EXPLORER_URL=https://pharosscan.xyz
SVG_MAX_BYTES=24576
GAS_LIMIT_BUFFER=120
```

## Service Agent integration

When invoked by an Anvita Flow Steward Agent, each operation maps to
one x402 charge (configured in the Developer Console Agent Card):

| Steward request                  | Runtime call             |
| -------------------------------- | ------------------------ |
| "Generate an SVG with seed N"    | `generateSVG({ seed: N })` |
| "Validate this SVG"              | `validateSVG(svg)`       |
| "Deploy a collection"            | `deployCollection({...})` |
| "Mint token #N to address"       | `mintSVG({...})`         |
| "Read token #N metadata"         | `readToken({...})`       |

The runtime returns plain JSON-serializable objects so the Steward
Agent can stream results back to the user.