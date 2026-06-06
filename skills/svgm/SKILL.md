---
name: svgm
description: Generate, validate, and mint onchain SVG NFTs on Pharos Network. Use when an agent needs to produce deterministic SVG artwork, store it fully onchain (no IPFS, no external hosting), and deploy/mint an ERC-721 token whose tokenURI returns the SVG directly. Triggers on "onchain svg", "mint svg nft", "pharos nft", "svg minter", "deploy svg collection", "onchain art", "tokenize svg", "pharos erc721 svg".
license: MIT
metadata:
  author: yemiight02
  version: "1.0.0"
  category: onchain-art
  chain: pharos
---

# Onchain SVG Minter (SVGM)

A portable agent skill for generating onchain SVG artwork and minting it as ERC-721 NFTs directly on the Pharos Network. All metadata and image data live in the contract's storage and `tokenURI` response — no IPFS, no Arweave, no external host.

## Network

| Field | Value |
|---|---|
| Network | Pharos Mainnet |
| Chain ID | 1672 |
| RPC URL | `https://rpc.pharos.xyz` |
| Explorer | `https://pharosscan.xyz` |
| Currency | PROS (18 decimals) |
| EVM | Equivalent — use standard Solidity 0.8.x tooling |

A Pharos Atlantic Testnet configuration is also supported for pre-production testing:

| Field | Value |
|---|---|
| Network | Pharos Atlantic Testnet |
| Chain ID | 688688 |
| RPC URL | `https://atlantic.dplabs-internal.com` |
| Explorer | `https://testnet.pharosscan.xyz` |

All onchain actions default to mainnet; switch to testnet by overriding the `RPC_URL`, `CHAIN_ID`, and `EXPLORER_URL` environment variables described below.

## Framework

- **Smart contracts**: Solidity 0.8.24, OpenZeppelin Contracts v5.x
- **Agent runtime**: Node.js 18+ with `viem` 2.x for typed EVM interaction
- **Tooling**: `hardhat` 2.x (compile + test), `solhint` (lint), `prettier-plugin-solidity` (format)
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
│       └── SKILL.md                  ← this file
├── contracts/
│   ├── OnchainSVG.sol                ← ERC-721 with onchain SVG tokenURI
│   ├── SVGMinter.sol                 ← factory + mint helper
│   └── interfaces/
│       └── ISVGMinter.sol
├── agent/
│   ├── package.json
│   ├── tsconfig.json
│   ├── .env.example
│   └── scripts/
│       ├── generate-svg.ts           ← deterministic SVG generator
│       ├── validate-svg.ts           ← XML well-formedness check
│       ├── deploy-collection.ts      ← deploy OnchainSVG to Pharos
│       ├── mint.ts                   ← mint a token (with prompt)
│       ├── read-token.ts             ← read onchain SVG and metadata
│       └── lib/
│           ├── pharos.ts             ← chain config + clients
│           ├── ipfs.ts               ← no-op (kept for parity)
│           └── types.ts
├── docs/
│   ├── ARCHITECTURE.md
│   └── SECURITY.md
├── hardhat.config.ts
├── package.json
├── .gitignore
├── LICENSE
└── README.md
```

## Quick Start

### 1. Install

```bash
git clone https://github.com/Yemiight02/SVGM
cd SVGM
npm install
cd agent && npm install && cd ..
```

### 2. Configure

```bash
cp .env.example .env
# Required:
#   PRIVATE_KEY              — deployer/minter EOA key
#   PHAROS_RPC_URL           — defaults to https://rpc.pharos.xyz (mainnet)
# Optional:
#   CHAIN_ID                 — defaults to 1672 (mainnet). Use 688688 for testnet.
#   EXPLORER_URL             — defaults to https://pharosscan.xyz
```

### 3. Compile contracts

```bash
npx hardhat compile
```

### 4. Deploy a collection

```bash
npx hardhat run scripts/deploy.ts --network pharos
# or use the agent wrapper:
npx ts-node agent/scripts/deploy-collection.ts --name "Pharos Genesis" --symbol "PHG" --base-uri ""
```

### 5. Mint

```bash
# Mint with an inline SVG
npx ts-node agent/scripts/mint.ts \
  --collection 0xYourCollection \
  --to 0xRecipient \
  --svg-file ./my-art.svg

# Mint with a generated prompt
npx ts-node agent/scripts/mint.ts \
  --collection 0xYourCollection \
  --to 0xRecipient \
  --prompt '{"shapes":["circle","rect"],"palette":["#2F80ED","#0D0D0D","#FFFFFF"],"seed":42}'
```

### 6. Read a token

```bash
npx ts-node agent/scripts/read-token.ts --collection 0xYourCollection --token-id 1
```

## Programmatic Use

### Generate SVG

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

### Validate SVG

```typescript
import { validateSVG } from "./agent/scripts/validate-svg";

const { ok, errors } = validateSVG(svgString);
if (!ok) throw new Error(`Invalid SVG: ${errors.join(", ")}`);
```

### Mint on Pharos

```typescript
import { createPublicClient, createWalletClient, http } from "viem";
import { pharosMainnet } from "./agent/lib/pharos";
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
function tokenURI(uint256 tokenId) external view returns (string memory);
function totalSupply() external view returns (uint256);
event Minted(address indexed to, uint256 indexed tokenId, string svgHash);
```

The contract returns a fully-formed `data:application/json;base64,...` URI from `tokenURI`, embedding the SVG and metadata in a single response. This means marketplaces and wallets see the artwork without any external fetch.

### `SVGMinter` (factory)

```solidity
function createCollection(string calldata name, string calldata symbol, address owner) external returns (address collection);
function mintTo(address collection, address to, string calldata svg) external returns (uint256 tokenId);
```

Use `SVGMinter` when an agent needs to deploy fresh collections on the fly without keeping a separate factory deployment per project.

## Agent Workflow

When the user asks the agent to do anything in the onchain-SVG-NFT space, the recommended flow is:

1. **Plan**: clarify whether the user wants a new collection, a single mint, or a generated artwork
2. **Generate** (if no SVG supplied): call `generateSVG` with a structured prompt
3. **Validate**: always run `validateSVG` before sending a transaction
4. **Estimate gas**: use `publicClient.estimateContractGas` to fail fast on out-of-gas
5. **Send**: call `mint` or `mintTo` on the deployed collection
6. **Confirm**: wait for the receipt and return the Pharoscan link

## Security Notes

- The onchain SVG is stored as a string and may be expensive. Keep individual SVGs under ~24 KB to stay safely within Pharos block gas limits at the time of writing.
- The minter is `Ownable`; the deployer retains admin rights. Agents should disclose ownership to the user before deploying.
- Do not include `<script>` tags in SVGs — they will be rejected by `validateSVG`. The contract itself strips any `<script>` / `on*=` attributes as a defense-in-depth measure.
- See `docs/SECURITY.md` for the full threat model.

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `PRIVATE_KEY` | yes | — | EOA key used for deploy/mint (hex, with or without `0x`) |
| `PHAROS_RPC_URL` | no | `https://rpc.pharos.xyz` | JSON-RPC endpoint |
| `CHAIN_ID` | no | `1672` | `1672` mainnet, `688688` testnet |
| `EXPLORER_URL` | no | `https://pharosscan.xyz` | Used to build transaction links |
| `GAS_LIMIT_BUFFER` | no | `120` | Percent buffer added to `estimateGas` |
| `SVG_MAX_BYTES` | no | `24576` | Reject SVGs larger than this |

## Limitations

- Pure EVM only — no Stylus, no WASM contracts.
- Designed for 1-of-1 mints; no batch minting helper in v1.
- The skill ships with one deterministic generator (shapes + palette + seed). Plug your own generator in `agent/scripts/generate-svg.ts` if you need parametric / trait-based output.

## Resources

- Pharos docs: https://docs.pharos.xyz
- Pharos mainnet explorer: https://pharosscan.xyz
- OpenZeppelin Contracts: https://docs.openzeppelin.com/contracts
- viem: https://viem.sh
