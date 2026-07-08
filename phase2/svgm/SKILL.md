---
name: svgm
description: Generate, validate, and mint fully-onchain SVG NFTs on Pharos Network using Foundry + viem. Use when an agent or user needs deterministic SVG artwork stored entirely in the contract (no IPFS, no Arweave, no external hosting), an ERC-721 collection whose tokenURI returns the SVG inline as a data URI, or batch minting of onchain art on Pharos mainnet (chain 1672) or Atlantic testnet (chain 688688). Triggers on "onchain svg", "mint svg nft", "pharos nft", "svg minter", "deploy svg collection", "onchain art", "tokenize svg", "pharos erc721 svg", "foundry svg", "forge deploy", "x402 art", "agent mint nft". Do NOT use for IPFS-pinned NFTs, large raster images, soulbound gated mints, or non-Pharos chains.
license: MIT
metadata:
  author: SVGM-builder
  version: "2.0.0"
  category: onchain-art
  chain: pharos
  toolchain: foundry
  runtime: viem
  payment: x402-pros
  endpoint: "https://flow.anvita.xyz/agent/svgm"
---

# SVGM — Onchain SVG Minter (Pharos Agent Skill)

A portable agent skill for the Pharos Network that generates onchain SVG
artwork and mints it as ERC-721 NFTs. All metadata and image data live in
the contract's storage and `tokenURI` response — no IPFS, no Arweave, no
external host. The full smart-contract toolchain is **Foundry**; the
agent runtime is **Node.js + viem**.

## When to Use

Activate this skill when the user (or a Steward Agent on Anvita Flow)
needs to:

- Create a fully onchain SVG NFT (no off-chain dependencies)
- Deploy a new ERC-721 collection whose `tokenURI` returns the SVG inline
- Mint an existing SVGM collection to a recipient address
- Batch-mint up to 50 tokens in one transaction (`mintBatch` or
  `mintBatchDistinct`)
- Generate deterministic SVG art from a structured prompt
  (shapes, palette, seed)
- Validate that a string is well-formed SVG before sending a transaction
- Estimate gas for a mint or a collection deployment on Pharos

**Do NOT** use this skill for IPFS-pinned NFTs, large raster images,
soulbound-style gated mints, or any chain other than Pharos. Use a
different skill for those.

## Network

| Field             | Value                                       |
| ----------------- | ------------------------------------------- |
| Network           | Pharos Mainnet                              |
| Chain ID          | 1672                                        |
| RPC URL           | `https://rpc.pharos.xyz`                    |
| Explorer          | `https://pharosscan.xyz`                    |
| Currency          | PROS (18 decimals)                          |

Atlantic Testnet is also supported:

| Field    | Value                                   |
| -------- | --------------------------------------- |
| Chain ID | 688688                                  |
| RPC URL  | `https://atlantic.dplabs-internal.com`  |
| Explorer | `https://testnet.pharosscan.xyz`        |

Default to mainnet; switch to testnet by passing `--rpc-url
https://atlantic.dplabs-internal.com` or setting `CHAIN_ID=688688`.

## Toolchain

- **Smart contracts**: Solidity 0.8.24, OpenZeppelin Contracts v5.x
- **Agent runtime**: Node.js 18+ with `viem` 2.x
- **Tooling**: Foundry (`forge`, `cast`, `anvil`)
- **Standard**: ERC-721 + ERC-721URIStorage with onchain metadata
  extension

## Repository Layout

```
SVGM/
├── skills/svgm/SKILL.md                  ← Anthropic Agent Skill spec
├── contracts/
│   ├── OnchainSVG.sol                    ← ERC-721 with onchain SVG tokenURI
│   ├── SVGMinter.sol                     ← factory + mint helper
│   └── interfaces/ISVGMinter.sol
├── script/
│   ├── Deploy.s.sol                      ← DeployCollection + DeployFactory
│   ├── Mint.s.sol                        ← Foundry mint script (env-driven)
│   └── CreateCollectionViaFactory.s.sol  ← factory-driven deploy + first mint
├── test/
│   ├── OnchainSVG.t.sol                  ← unit + property fuzz (svg safety)
│   └── SVGMinter.t.sol                   ← factory + ownership behavior
├── agent/
│   ├── package.json
│   ├── tsconfig.json
│   ├── .env.example
│   └── scripts/
│       ├── generate-svg.ts               ← deterministic SVG generator
│       ├── validate-svg.ts               ← XML well-formedness + safety check
│       ├── deploy-collection.ts          ← viem deploy (reads Foundry out/)
│       ├── mint.ts                       ← viem mint (reads env)
│       ├── read-token.ts                 ← reads onchain SVG + metadata
│       └── lib/
│           ├── pharos.ts                 ← chain config + clients
│           ├── foundry-artifact.ts       ← load out/<Contract>.sol/<Contract>.json
│           └── types.ts
├── lib/                                  ← vendored forge-std + OpenZeppelin
├── foundry.toml                          ← Foundry config (RPC, optimizer)
├── remappings.txt                        ← forge-std/, @openzeppelin/contracts/
├── Makefile                              ← one-liner targets
├── docs/
│   ├── ARCHITECTURE.md
│   └── SECURITY.md
└── README.md
```

## Quick Start

### 1. Install Foundry

```bash
# Download first, inspect, then run
curl -L https://foundry.paradigm.xyz -o foundryup.sh
# Optional: cat foundryup.sh | head -20   # inspect before running
sh foundryup.sh
foundryup
```

### 2. Clone and configure

```bash
git clone https://github.com/Yemiight02/SVGM
cd SVGM
cp .env.example .env
# fill in PRIVATE_KEY (and PHAROS_RPC_URL if not mainnet)
```

> `lib/` is vendored in this repo, so no separate `forge install` is needed.

### 3. Build, test, format

```bash
forge build                 # compile contracts
forge test                  # 29 unit + property-fuzz tests
forge fmt --check           # CI-friendly formatter check
```

Or, equivalently:

```bash
make build
make test
make fmt
```

### 4. Deploy a collection

```bash
# Mainnet (default)
forge script script/Deploy.s.sol:DeployCollection \
  --rpc-url $PHAROS_RPC_URL --broadcast

# Custom name/symbol
COLLECTION_NAME="Pixel Pals" COLLECTION_SYMBOL="PPLS" \
  forge script script/Deploy.s.sol:DeployCollection \
    --rpc-url $PHAROS_RPC_URL --broadcast

# Makefile shortcut
make deploy-collection NAME="Pixel Pals" SYMBOL="PPLS"
```

The deploy script reads `PRIVATE_KEY` from env (or `.env` via the
Makefile) and broadcasts to the configured RPC. The deployed address is
logged to stdout.

### 5. Mint

```bash
# Mint from an inline SVG file
COLLECTION=0xYourCollection RECIPIENT=0xRecipient \
SVG_FILE=./art.svg TOKEN_NAME="Gen #1" TOKEN_DESC="First onchain pixel" \
  forge script script/Mint.s.sol:Mint --rpc-url $PHAROS_RPC_URL --broadcast

# Makefile shortcut
make mint COLLECTION=0xYourCollection RECIPIENT=0xRecipient SVG_FILE=./art.svg

# Mint with a generated prompt (agent-friendly)
COLLECTION=0xYourCollection RECIPIENT=0xRecipient \
SVG_BODY='<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" .../>' \
  forge script script/Mint.s.sol:Mint --rpc-url $PHAROS_RPC_URL --broadcast
```

### 6. Batch mint

```bash
# Same SVG to one recipient (fixed-edition drop)
COLLECTION=0xYourCollection RECIPIENT=0xRecipient \
SVG_FILE=./art.svg BATCH_COUNT=10 \
  forge script script/Mint.s.sol:MintBatch --rpc-url $PHAROS_RPC_URL --broadcast

# Distinct SVGs to distinct recipients
COLLECTION=0xYourCollection \
RECIPIENTS_FILE=./recipients.csv SVGS_FILE=./svgs.csv \
  forge script script/Mint.s.sol:MintBatchDistinct --rpc-url $PHAROS_RPC_URL --broadcast
```

### 7. Read a token

```bash
cast call 0xYourCollection "tokenURI(uint256)(string)" 1 --rpc-url $PHAROS_RPC_URL
# full decode via the agent runtime
npx ts-node agent/scripts/read-token.ts --collection 0xYourCollection --token-id 1
```

## Programmatic Use

### Generate SVG

```typescript
import { generateSVG } from "./scripts/generate-svg";

const svg = generateSVG({
  shapes: ["circle", "rect", "polygon"],
  palette: ["#2F80ED", "#0D0D0D", "#F5F5F5"],
  seed: 7,
  size: 512,
});
// returns a well-formed SVG string (UTF-8, XML-safe)
```

### Validate SVG

```typescript
import { validateSVG } from "./scripts/validate-svg";

const { ok, errors } = validateSVG(svgString);
if (!ok) throw new Error(`Invalid SVG: ${errors.join(", ")}`);
```

### Mint on Pharos

```typescript
import { createPublicClient, createWalletClient, http } from "viem";
import { pharosMainnet } from "./scripts/lib/pharos";
import { mintSVG, mintBatchSVG, mintBatchDistinctSVG } from "./scripts/mint";

const publicClient = createPublicClient({
  chain: pharosMainnet, transport: http(),
});
const walletClient = createWalletClient({
  chain: pharosMainnet, transport: http(), account,
});

// Single mint
const { txHash, tokenId } = await mintSVG({
  publicClient, walletClient,
  collection: "0xYourCollection",
  to: "0xRecipient",
  svg: svgString,
});
console.log(`Minted #${tokenId} → https://pharosscan.xyz/tx/${txHash}`);

// Batch mint (fixed-edition)
const batch = await mintBatchSVG({
  publicClient, walletClient,
  collection: "0xYourCollection",
  to: "0xRecipient",
  svg: svgString,
  count: 10,        // max 50 (MAX_BATCH_SIZE)
});
console.log(`Minted ${batch.fromTokenId}..${batch.toTokenId} → ${batch.explorerUrl}`);
```

## Contract API

### `OnchainSVG`

```solidity
function mint(address to, string svg) external returns (uint256 tokenId);
function mintWithMetadata(
  address to, string svg, string name, string description
) external returns (uint256 tokenId);
function mintBatch(
  address to, string svg, uint256 count
) external returns (uint256 fromTokenId, uint256 toTokenId);
function mintBatchDistinct(
  address[] recipients, string[] svgs
) external returns (uint256 fromTokenId, uint256 toTokenId);
function setMetadata(uint256 tokenId, string name, string description) external;
function tokenURI(uint256 tokenId) external view returns (string);
function totalSupply() external view returns (uint256);
function MAX_BATCH_SIZE() external pure returns (uint256);  // 50

event Minted(address indexed to, uint256 indexed tokenId, string svgHash);
event BatchMinted(address indexed to, uint256 fromTokenId, uint256 toTokenId);
```

#### Batch minting

Two flavors of batch mint, both `onlyOwner` and both capped at
`MAX_BATCH_SIZE = 50`:

- **`mintBatch(to, svg, count)`** — fixed-edition drop. Mints `count`
  tokens, all sharing the same onchain SVG, to a single recipient.
  Cheap because size + safety checks run once before the loop.
- **`mintBatchDistinct(recipients, svgs)`** — one token per pair. Arrays
  must be the same length. **Atomic**: if any single item is empty,
  oversize, or forbidden, the whole batch reverts and nothing is
  minted.

For both, a single `BatchMinted(to, fromTokenId, toTokenId)` event is
emitted after the loop, in addition to the per-token `Minted` events.

The contract returns a fully-formed
`data:application/json;base64,...` URI from `tokenURI`, embedding the
SVG and metadata in a single response. Marketplaces and wallets see the
artwork without any external fetch.

### `SVGMinter` (factory)

```solidity
function createCollection(
  string name, string symbol, address owner
) external returns (address collection);
function mintTo(
  address collection, address to, string svg
) external returns (uint256 tokenId);
```

Use `SVGMinter` when an agent needs to deploy fresh collections on the
fly. Note: `mintTo` is permissionless on the factory, but the underlying
`OnchainSVG.mint` is `onlyOwner`. The intended mint path is either
(a) the collection owner calls `OnchainSVG.mint` directly, or
(b) deploy collections via the factory and mint through `OnchainSVG`.
The Foundry test suite documents this with explicit revert assertions.

## Agent Workflow

When a user (or Steward Agent on Anvita Flow) requests an action in the
onchain-SVG-NFT space, follow this flow:

1. **Plan** — clarify whether the user wants a new collection, a single
   mint, a generated artwork, or a batch drop.
2. **Build** (once per session) — `forge build`. Produces
   `out/OnchainSVG.sol/OnchainSVG.json` for the agent runtime to read.
3. **Generate** (if no SVG supplied) — call `generateSVG` with a
   structured prompt: shapes, palette, seed, size.
4. **Validate** — always run `validateSVG` before sending a transaction.
   This rejects empty / oversize SVGs and any with `<script>` or
   forbidden tags.
5. **Estimate gas** — use `publicClient.estimateContractGas` to fail
   fast on out-of-gas before the user pays.
6. **Send** — call `mintSVG` (or `mintWithMetadata`,
   `mintBatchSVG`, `mintBatchDistinctSVG`) from the runtime, or
   invoke the Foundry scripts at `script/Mint.s.sol` for env-driven
   deploys.
7. **Confirm** — wait for the receipt and return the Pharoscan link.

### x402 Payment (Anvita Flow)

When running as a Service Agent on Anvita Flow, every call is gated by
x402 payment in PROS. The agent's pricing tier is configured in the
Developer Console; users authorize payment automatically via their
wallet's x402 client. Suggested pricing tiers for SVG minting on Pharos:

| Operation | Suggested x402 price (PROS) |
| --------- | --------------------------- |
| Generate SVG (no chain action) | 0.001 |
| Validate SVG | free (no payment required) |
| Mint single NFT | 0.005 + gas reimbursement |
| Mint batch of N | 0.005 × N + gas reimbursement |
| Deploy new collection | 0.02 + gas reimbursement |

These are suggestions; set your own in the Developer Console Agent Card.

## Security Notes

- The onchain SVG is stored as a string and may be expensive. Keep
  individual SVGs under ~24 KiB to stay safely within Pharos block gas
  limits.
- The minter is `Ownable`; the deployer retains admin rights. Agents
  should disclose ownership to the user before deploying.
- Do not include `<script>` tags in SVGs — they are rejected by
  `validateSVG` *and* by `_enforceSafe` in the contract (defense in
  depth).
- See `references/SECURITY.md` for the full threat model.

## Environment Variables

| Variable               | Required | Default                              | Description                                                     |
| ---------------------- | -------- | ------------------------------------ | --------------------------------------------------------------- |
| `PRIVATE_KEY`          | yes      | —                                    | EOA key for deploy/mint (hex, with or without `0x`)             |
| `PHAROS_RPC_URL`       | no       | `https://rpc.pharos.xyz`             | JSON-RPC endpoint                                               |
| `CHAIN_ID`             | no       | `1672`                               | `1672` mainnet, `688688` testnet                                |
| `EXPLORER_URL`         | no       | `https://pharosscan.xyz`             | Used to build transaction links                                 |
| `GAS_LIMIT_BUFFER`     | no       | `120`                                | Percent buffer added to `estimateGas` (agent runtime only)      |
| `SVG_MAX_BYTES`        | no       | `24576`                              | Reject SVGs larger than this (24 KiB)                           |
| `PHAROSCAN_API_KEY`    | no       | —                                    | API key for `forge verify-contract` on Pharoscan                |
| `FORGE_ARTIFACT_PATH`  | no       | `out/OnchainSVG.sol/OnchainSVG.json` | Override the artifact path used by `deploy-collection.ts`        |

## Limitations

- Pure EVM only — no Stylus, no WASM contracts.
- The skill ships with one deterministic generator (shapes + palette +
  seed). Plug your own generator in `agent/scripts/generate-svg.ts` if
  you need parametric / trait-based output.

## Resources

- Pharos docs: https://docs.pharos.xyz
- Pharos Foundry guide: https://docs.pharos.xyz/developer-guide/foundry
- Pharos mainnet explorer: https://pharosscan.xyz
- Anvita Flow Developer Console: https://flow.anvita.xyz/service-agents
- x402 protocol spec: https://www.x402.org/x402-whitepaper.pdf
- OpenZeppelin Contracts: https://docs.openzeppelin.com/contracts
- Foundry book: https://book.getfoundry.sh
- viem: https://viem.sh
- Anthropic Agent Skills spec: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview