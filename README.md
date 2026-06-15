# Onchain SVG Minter (SVGM)

Generate, validate, and mint fully-onchain SVG NFTs on **Pharos Network**. No IPFS, no external hosting — the artwork and metadata live in the contract itself and are returned as a base64 `data:` URI from `tokenURI()`.

This repository ships:

- **`skills/svgm/SKILL.md`** — the agent skill definition (YAML frontmatter + instructions) consumed by Agent Center-style skill engines.
- **`contracts/`** — `OnchainSVG.sol` (ERC-721 + onchain metadata) and `SVGMinter.sol` (factory + mint helper), built on OpenZeppelin v5.
- **`script/`** — Foundry deployment scripts (`Deploy.s.sol`, `Mint.s.sol`, `CreateCollectionViaFactory.s.sol`).
- **`test/`** — Foundry tests in Solidity (`OnchainSVG.t.sol`, `SVGMinter.t.sol`) including a property-based fuzz on SVG safety.
- **`agent/`** — a small viem-based runtime (TypeScript) that lets an agent generate, validate, deploy, mint, and read SVGs from the command line or programmatically. Reads bytecode/ABI directly from Foundry's `out/` directory.
- **`Makefile`** — one-liner targets for `build`, `test`, `deploy-collection`, `mint`, `verify`, etc.

## Network

| Network                          | Chain ID | RPC                                  | Explorer                          | Currency |
| -------------------------------- | -------- | ------------------------------------ | --------------------------------- | -------- |
| **Pharos Mainnet** *(default)*   | `1672`   | `https://rpc.pharos.xyz`             | `https://pharosscan.xyz`          | PROS     |
| Pharos Atlantic Testnet          | `688688` | `https://atlantic.dplabs-internal.com` | `https://testnet.pharosscan.xyz`  | PROS     |

All onchain actions default to **Pharos Mainnet**. Switch to the testnet by passing `--rpc-url https://atlantic.dplabs-internal.com` to `forge script` / `cast`.

## Framework

- **Smart contracts** — Solidity `0.8.24`, OpenZeppelin Contracts `v5.x`, Foundry `1.x` (`forge build`, `forge test`, `forge script`).
- **Agent runtime** — Node.js `>=18`, TypeScript `5.x`, viem `2.x`. Reads bytecode/ABI from Foundry's `out/OnchainSVG.sol/OnchainSVG.json` (no Hardhat artifacts).
- **Skill format** — `SKILL.md` with YAML frontmatter (`name`, `description`, `license`, `metadata`), Markdown body.
- **Token standard** — ERC-721 + ERC-721URIStorage, with onchain metadata (base64 `data:application/json`).
- **Tooling** — `forge fmt`, `forge coverage`, `forge snapshot`.

## Repository Layout

```
SVGM/
├── skills/svgm/SKILL.md
├── contracts/
│   ├── OnchainSVG.sol
│   ├── SVGMinter.sol
│   └── interfaces/ISVGMinter.sol
├── script/
│   ├── Deploy.s.sol
│   ├── Mint.s.sol
│   └── CreateCollectionViaFactory.s.sol
├── test/
│   ├── OnchainSVG.t.sol
│   └── SVGMinter.t.sol
├── agent/
│   ├── package.json
│   ├── tsconfig.json
│   ├── .env.example
│   └── scripts/
│       ├── generate-svg.ts
│       ├── validate-svg.ts
│       ├── deploy-collection.ts
│       ├── mint.ts
│       ├── read-token.ts
│       └── lib/
│           ├── pharos.ts
│           ├── foundry-artifact.ts
│           ├── ipfs.ts
│           └── types.ts
├── lib/                       (vendored: forge-std, OpenZeppelin)
├── docs/
│   ├── ARCHITECTURE.md
│   └── SECURITY.md
├── .github/workflows/ci.yml
├── foundry.toml
├── remappings.txt
├── Makefile
├── .env.example
├── LICENSE
└── README.md
```

## Installation

```bash
# 1. Install Foundry (one-time)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 2. Clone and set up
git clone https://github.com/Yemiight02/SVGM
cd SVGM

# 3. (If lib/ is not vendored) install dependencies
make install-libs

# 4. Configure
cp .env.example .env
# fill in PRIVATE_KEY
# (optionally) install agent runtime deps
cd agent && npm install && cd ..
```

## Quick Start

### 1. Compile contracts

```bash
forge build
```

### 2. Run the test suite

```bash
forge test
# expected: 18 tests passed (13 OnchainSVG + 5 SVGMinter, includes property fuzz)
```

### 3. Deploy a collection to Pharos Mainnet

```bash
COLLECTION_NAME="Pharos Genesis" COLLECTION_SYMBOL="PHG" \
  forge script script/Deploy.s.sol:DeployCollection \
    --rpc-url $PHAROS_RPC_URL --broadcast
```

Or, equivalently, with the Makefile:

```bash
make deploy-collection NAME="Pharos Genesis" SYMBOL="PHG"
```

### 4. Mint

```bash
COLLECTION=0xYourCollection RECIPIENT=0xRecipient \
SVG_FILE=./my-art.svg TOKEN_NAME="Genesis #1" TOKEN_DESC="First onchain SVG of the Pharos Genesis collection." \
  forge script script/Mint.s.sol:Mint --rpc-url $PHAROS_RPC_URL --broadcast
```

### 5. Read a token

```bash
# Quick view with cast
cast call 0xYourCollection "tokenURI(uint256)(string)" 1 --rpc-url $PHAROS_RPC_URL

# Or use the agent runtime for a full decode
npx ts-node agent/scripts/read-token.ts --collection 0xYourCollection --token-id 1
```

The response includes the onchain `tokenURI`, the decoded metadata JSON, and a `data:image/svg+xml;base64,...` image URI that can be opened directly in any browser.

## Skill Loading

The `skills/svgm/SKILL.md` file is the consumable unit. Any agent runtime that follows the standard skill format (YAML frontmatter + Markdown body) can load it. Key metadata:

```yaml
name: svgm
description: Generate, validate, and mint onchain SVG NFTs on Pharos Network using Foundry. ...
license: MIT
metadata:
  author: yemiight02
  version: "1.1.0"
  category: onchain-art
  chain: pharos
  toolchain: foundry
```

The description field is the routing key — agents match user intents like "mint an SVG NFT on Pharos" or "deploy an onchain art collection" against it. See `skills/svgm/SKILL.md` for the full trigger list and execution workflow.

## Programmatic Use

```typescript
import { generateSVG } from "./agent/scripts/generate-svg";
import { validateSVG } from "./agent/scripts/validate-svg";
import { getClients } from "./agent/scripts/lib/pharos";
import { mintSVG } from "./agent/scripts/mint";

const svg = generateSVG({
    shapes: ["circle", "rect", "polygon"],
    palette: ["#2F80ED", "#0D0D0D", "#F5F5F5"],
    seed: 7,
    size: 512,
});

const v = validateSVG(svg);
if (!v.ok) throw new Error(v.errors.join("; "));

const { publicClient, walletClient, account } = getClients("mainnet");

const result = await mintSVG({
    publicClient,
    walletClient,
    account: account.address,
    collection: "0xYourCollection",
    to: "0xRecipient",
    svg,
    name: "Generated #1",
    description: "Mint via SVGM agent skill",
    network: "mainnet",
});

console.log(result.explorerUrl);
```

> The deploy-collection script (`agent/scripts/deploy-collection.ts`) reads bytecode and ABI directly from `out/OnchainSVG.sol/OnchainSVG.json` after `forge build`. Override the path with the `FORGE_ARTIFACT_PATH` env var.

## Security

- The onchain SVG validator strips `<script>` tags, `javascript:` URIs, and `on*=` event-handler attributes. The contract enforces the same restrictions as a second line of defense.
- All mints are `onlyOwner` — the collection deployer is the admin. Agents should disclose ownership to the user before deploying.
- A 24 KiB SVG size cap is enforced both client-side and onchain to keep individual mints safely inside Pharos block gas limits.
- Private keys are read from environment variables only. Never commit `.env`.
- See [`docs/SECURITY.md`](docs/SECURITY.md) for the full threat model.

## Environment Variables

| Variable            | Required | Default                              | Description                                                     |
| ------------------- | -------- | ------------------------------------ | --------------------------------------------------------------- |
| `PRIVATE_KEY`       | yes      | —                                    | EOA key (hex, with or without `0x`) used to deploy and mint     |
| `PHAROS_RPC_URL`    | no       | `https://rpc.pharos.xyz`             | JSON-RPC endpoint                                               |
| `CHAIN_ID`          | no       | `1672`                               | `1672` for mainnet, `688688` for testnet                        |
| `EXPLORER_URL`      | no       | `https://pharosscan.xyz`             | Used to build transaction links                                 |
| `GAS_LIMIT_BUFFER`  | no       | `120`                                | Percent buffer added to `estimateGas`                           |
| `SVG_MAX_BYTES`     | no       | `24576`                              | Reject SVGs larger than this (24 KiB)                           |
| `PHAROSCAN_API_KEY` | no       | —                                    | API key for `forge verify-contract` on Pharoscan                |
| `FORGE_ARTIFACT_PATH` | no     | `out/OnchainSVG.sol/OnchainSVG.json` | Override the artifact path used by the agent deploy-collection  |

## Limitations

- EVM only. No Stylus, no WASM contracts.
- 1-of-1 mints in this version — no batch minting helper yet.
- The default SVG generator is shape + palette + seed based. Plug a richer generator into `agent/scripts/generate-svg.ts` for trait / parametric output.

## License

MIT — see [`LICENSE`](LICENSE).
