---
name: svgm
description: Generate, validate, and mint onchain SVG NFTs on Pharos Network using Foundry. Use when an agent needs to produce deterministic SVG artwork, store it fully onchain (no IPFS, no external hosting), and deploy/mint an ERC-721 token whose tokenURI returns the SVG directly. Triggers on "onchain svg", "mint svg nft", "pharos nft", "svg minter", "deploy svg collection", "onchain art", "tokenize svg", "pharos erc721 svg", "foundry svg", "forge deploy".
license: MIT
metadata:
  author: yemiight02
  version: "1.1.0"
  category: onchain-art
  chain: pharos
  toolchain: foundry
---

# Onchain SVG Minter (SVGM)

A portable agent skill for generating onchain SVG artwork and minting it as ERC-721 NFTs directly on the Pharos Network. All metadata and image data live in the contract's storage and `tokenURI` response — no IPFS, no Arweave, no external host. The full smart-contract toolchain is **Foundry** (`forge build`, `forge test`, `forge script`); no Hardhat required.

## Network

| Field             | Value                                                |
| ----------------- | ---------------------------------------------------- |
| Network           | Pharos Mainnet                                       |
| Chain ID          | 1672                                                 |
| RPC URL           | `https://rpc.pharos.xyz`                             |
| Explorer          | `https://pharosscan.xyz`                             |
| Currency          | PROS (18 decimals)                                   |
| EVM               | Equivalent — use standard Solidity 0.8.x tooling     |
| Toolchain         | **Foundry** (`forge`, `cast`, `anvil`)               |

A Pharos Atlantic Testnet configuration is also supported for pre-production testing:

| Field    | Value                                  |
| -------- | -------------------------------------- |
| Network  | Pharos Atlantic Testnet                |
| Chain ID | 688688                                 |
| RPC URL  | `https://atlantic.dplabs-internal.com` |
| Explorer | `https://testnet.pharosscan.xyz`       |

All onchain actions default to mainnet; switch to testnet by passing `--rpc-url https://atlantic.dplabs-internal.com` to `forge script`/`cast`.

## Framework

- **Smart contracts**: Solidity 0.8.24, OpenZeppelin Contracts v5.x
- **Agent runtime**: Node.js 18+ with `viem` 2.x for typed EVM interaction
- **Tooling**: **Foundry** (`forge` for build/test/script, `cast` for read calls, `anvil` for local node), `forge fmt`, `forge coverage`
- **Standard**: ERC-721 + ERC-721URIStorage, with the onchain metadata extension where the metadata JSON itself is rendered from contract storage

## When to Use

Activate this skill when the agent must:

- Create a fully onchain SVG NFT (no off-chain dependencies)
- Deploy a new ERC-721 collection whose `tokenURI` returns the SVG inline
- Mint an existing SVGM collection to a recipient address
- Generate deterministic SVG art from a structured prompt (shapes, palette, seed)
- Validate that a string is well-formed SVG before sending a transaction
- Estimate gas for a mint or a collection deployment on Pharos

Do **not** use this skill for IPFS-pinned NFTs, large raster images, soulbound-style gated mints, or any chain other than Pharos. Use a different skill for those.

## Repository Layout

```
SVGM/
├── skills/
│   └── svgm/
│       └── SKILL.md                       ← this file
├── contracts/
│   ├── OnchainSVG.sol                     ← ERC-721 with onchain SVG tokenURI
│   ├── SVGMinter.sol                      ← factory + mint helper
│   └── interfaces/
│       └── ISVGMinter.sol
├── script/
│   ├── Deploy.s.sol                       ← DeployCollection + DeployFactory
│   ├── Mint.s.sol                         ← Foundry mint script (env-driven)
│   └── CreateCollectionViaFactory.s.sol   ← factory-driven deploy + optional first mint
├── test/
│   ├── OnchainSVG.t.sol                   ← unit + property fuzz (svg safety)
│   └── SVGMinter.t.sol                    ← factory + ownership behavior
├── agent/
│   ├── package.json
│   ├── tsconfig.json
│   ├── .env.example
│   └── scripts/
│       ├── generate-svg.ts                ← deterministic SVG generator
│       ├── validate-svg.ts                ← XML well-formedness + safety check
│       ├── deploy-collection.ts           ← viem deploy (reads Foundry out/)
│       ├── mint.ts                        ← viem mint (reads env)
│       ├── read-token.ts                  ← reads onchain SVG + metadata
│       └── lib/
│           ├── pharos.ts                  ← chain config + clients
│           ├── foundry-artifact.ts        ← load out/<Contract>.sol/<Contract>.json
│           ├── ipfs.ts                    ← no-op (kept for parity)
│           └── types.ts
├── lib/                                   ← vendored (forge-std, OpenZeppelin)
├── foundry.toml                           ← Foundry config (RPC endpoints, optimizer)
├── remappings.txt                         ← forge-std/, @openzeppelin/contracts/
├── Makefile                               ← one-liner targets (build, test, deploy, mint, verify)
├── .env.example
├── .github/workflows/ci.yml               ← fmt + build + test on every PR
├── docs/
│   ├── ARCHITECTURE.md
│   └── SECURITY.md
├── LICENSE
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

### 2. Install the project

```bash
git clone https://github.com/Yemiight02/SVGM
cd SVGM
make install-libs   # vendors forge-std + OpenZeppelin into lib/
cp .env.example .env
# fill in PRIVATE_KEY (and PHAROS_RPC_URL if not mainnet)
```

> If you already have `lib/` checked in (this repo vendors it), you can skip `make install-libs`.

### 3. Build, test, format

```bash
forge build                 # compile contracts
forge test                  # 18 unit + property-fuzz tests, all should pass
forge fmt                   # auto-format Solidity
forge fmt --check           # CI-friendly: fails if any file would be reformatted
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

# With a custom name/symbol
COLLECTION_NAME="Pixel Pals" COLLECTION_SYMBOL="PPLS" \
  forge script script/Deploy.s.sol:DeployCollection \
    --rpc-url $PHAROS_RPC_URL --broadcast

# Or via the Makefile
make deploy-collection NAME="Pixel Pals" SYMBOL="PPLS"
```

The deployment script reads `PRIVATE_KEY` from your env (or `.env` via the Makefile) and broadcasts to the configured RPC. The deployed address is logged to stdout.

### 5. Mint

```bash
# Mint from an inline SVG file
COLLECTION=0xYourCollection RECIPIENT=0xRecipient \
SVG_FILE=./art.svg TOKEN_NAME="Gen #1" TOKEN_DESC="First onchain pixel" \
  forge script script/Mint.s.sol:Mint --rpc-url $PHAROS_RPC_URL --broadcast

# Or via the Makefile
make mint COLLECTION=0xYourCollection RECIPIENT=0xRecipient SVG_FILE=./art.svg

# Mint with a generated prompt (agent-friendly)
COLLECTION=0xYourCollection RECIPIENT=0xRecipient \
SVG_BODY='<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" .../>' \
  forge script script/Mint.s.sol:Mint --rpc-url $PHAROS_RPC_URL --broadcast
```

### 6. Read a token

```bash
# Quick read with cast
cast call 0xYourCollection "tokenURI(uint256)(string)" 1 --rpc-url $PHAROS_RPC_URL

# Full decode via the agent runtime
npx ts-node agent/scripts/read-token.ts --collection 0xYourCollection --token-id 1
```

## Programmatic Use

### Generate SVG (Node)

```typescript
import { generateSVG } from "./agent/scripts/generate-svg";

const svg = generateSVG({
    shapes: ["circle", "rect", "polygon"],
    palette: ["#2F80ED", "#0D0D0D", "#F5F5F5"],
    seed: 7,
    size: 512,
});
// returns a well-formed SVG string (UTF-8, XML-safe)
```

### Validate SVG (Node)

```typescript
import { validateSVG } from "./agent/scripts/validate-svg";

const { ok, errors } = validateSVG(svgString);
if (!ok) throw new Error(`Invalid SVG: ${errors.join(", ")}`);
```

### Mint on Pharos (Node)

```typescript
import { createPublicClient, createWalletClient, http } from "viem";
import { pharosMainnet } from "./agent/scripts/lib/pharos";
import { mintSVG } from "./agent/scripts/mint";

const publicClient = createPublicClient({ chain: pharosMainnet, transport: http() });
const walletClient = createWalletClient({ chain: pharosMainnet, transport: http(), account });

const { txHash, tokenId } = await mintSVG({
    publicClient,
    walletClient,
    collection: "0xYourCollection",
    to: "0xRecipient",
    svg: svgString,
});
console.log(`Minted token #${tokenId} → https://pharosscan.xyz/tx/${txHash}`);
```

## Contract API

### `OnchainSVG`

```solidity
function mint(address to, string calldata svg) external returns (uint256 tokenId);
function mintWithMetadata(address to, string calldata svg, string calldata name, string calldata description) external returns (uint256 tokenId);
function mintBatch(address to, string calldata svg, uint256 count) external returns (uint256 fromTokenId, uint256 toTokenId);
function mintBatchDistinct(address[] calldata recipients, string[] calldata svgs) external returns (uint256 fromTokenId, uint256 toTokenId);
function setMetadata(uint256 tokenId, string calldata name, string calldata description) external;
function tokenURI(uint256 tokenId) external view returns (string memory);
function totalSupply() external view returns (uint256);
function MAX_BATCH_SIZE() external pure returns (uint256);
event Minted(address indexed to, uint256 indexed tokenId, string svgHash);
event BatchMinted(address indexed to, uint256 fromTokenId, uint256 toTokenId);
```

#### Batch minting

Two flavors of batch mint, both `onlyOwner` and both cap at `MAX_BATCH_SIZE = 50`:

- `mintBatch(to, svg, count)` — fixed-edition drop. Mints `count` tokens, all sharing the same onchain SVG, to a single recipient. Cheap because size + safety checks run once before the loop.
- `mintBatchDistinct(recipients, svgs)` — one token per pair. Arrays must be the same length. **Atomic**: if any single item is empty / oversize / forbidden, the whole batch reverts and nothing is minted.

For both, a single `BatchMinted(to, fromTokenId, toTokenId)` event is emitted after the loop, in addition to the per-token `Minted` events.

The contract returns a fully-formed `data:application/json;base64,...` URI from `tokenURI`, embedding the SVG and metadata in a single response. This means marketplaces and wallets see the artwork without any external fetch.

### `SVGMinter` (factory)

```solidity
function createCollection(string calldata name, string calldata symbol, address owner) external returns (address collection);
function mintTo(address collection, address to, string calldata svg) external returns (uint256 tokenId);
```

Use `SVGMinter` when an agent needs to deploy fresh collections on the fly. Note: `mintTo` is permissionless on the factory, but the underlying `OnchainSVG.mint` is `onlyOwner`. The intended mint path is either (a) the collection owner calls `OnchainSVG.mint` directly, or (b) deploy collections via the factory and mint through `OnchainSVG`. The Foundry test suite documents this with explicit revert assertions.

## Agent Workflow

When the user asks the agent to do anything in the onchain-SVG-NFT space, the recommended flow is:

1. **Plan**: clarify whether the user wants a new collection, a single mint, or a generated artwork
2. **Build** (once per session): `forge build` — produces `out/OnchainSVG.sol/OnchainSVG.json`
3. **Generate** (if no SVG supplied): call `generateSVG` with a structured prompt
4. **Validate**: always run `validateSVG` before sending a transaction
5. **Estimate gas**: use `publicClient.estimateContractGas` to fail fast on out-of-gas
6. **Send**: call `mint` (or `mintWithMetadata`) on the deployed collection via `forge script script/Mint.s.sol`
7. **Confirm**: wait for the receipt and return the Pharoscan link

## Security Notes

- The onchain SVG is stored as a string and may be expensive. Keep individual SVGs under ~24 KiB to stay safely within Pharos block gas limits.
- The minter is `Ownable`; the deployer retains admin rights. Agents should disclose ownership to the user before deploying.
- Do not include `<script>` tags in SVGs — they will be rejected by `validateSVG` *and* by `_enforceSafe` in the contract (defense in depth).
- See `docs/SECURITY.md` for the full threat model.

## Environment Variables

| Variable            | Required | Default                              | Description                                                     |
| ------------------- | -------- | ------------------------------------ | --------------------------------------------------------------- |
| `PRIVATE_KEY`       | yes      | —                                    | EOA key used for deploy/mint (hex, with or without `0x`)        |
| `PHAROS_RPC_URL`    | no       | `https://rpc.pharos.xyz`             | JSON-RPC endpoint                                               |
| `CHAIN_ID`          | no       | `1672`                               | `1672` mainnet, `688688` testnet                                |
| `EXPLORER_URL`      | no       | `https://pharosscan.xyz`             | Used to build transaction links                                 |
| `GAS_LIMIT_BUFFER`  | no       | `120`                                | Percent buffer added to `estimateGas` (agent runtime only)      |
| `SVG_MAX_BYTES`     | no       | `24576`                              | Reject SVGs larger than this (24 KiB)                           |
| `PHAROSCAN_API_KEY` | no       | —                                    | API key for `forge verify-contract` on Pharoscan                |
| `FORGE_ARTIFACT_PATH` | no     | `out/OnchainSVG.sol/OnchainSVG.json` | Override the artifact path used by the agent deploy-collection   |

## Limitations

- Pure EVM only — no Stylus, no WASM contracts.
- Designed for 1-of-1 mints; no batch minting helper in this version.
- The skill ships with one deterministic generator (shapes + palette + seed). Plug your own generator in `agent/scripts/generate-svg.ts` if you need parametric / trait-based output.

## Resources

- Pharos docs: https://docs.pharos.xyz
- Pharos Foundry guide: https://docs.pharos.xyz/developer-guide/foundry
- Pharos mainnet explorer: https://pharosscan.xyz
- OpenZeppelin Contracts: https://docs.openzeppelin.com/contracts
- Foundry book: https://book.getfoundry.sh
- viem: https://viem.sh
