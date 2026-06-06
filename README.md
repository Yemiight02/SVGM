# Onchain SVG Minter (SVGM)

Generate, validate, and mint fully-onchain SVG NFTs on **Pharos Network**. No IPFS, no external hosting — the artwork and metadata live in the contract itself and are returned as a base64 `data:` URI from `tokenURI()`.

This repository ships:

- **`skills/svgm/SKILL.md`** — the agent skill definition (YAML frontmatter + instructions) consumed by Agent Center-style skill engines.
- **`contracts/`** — `OnchainSVG.sol` (ERC-721 + onchain metadata) and `SVGMinter.sol` (factory + mint helper), both built on OpenZeppelin v5.
- **`agent/`** — a small viem-based runtime (TypeScript) that lets an agent generate, validate, deploy, mint, and read SVGs from the command line or programmatically.

## Network

| Network | Chain ID | RPC | Explorer | Currency |
|---|---|---|---|---|
| **Pharos Mainnet** *(default)* | `1672` | `https://rpc.pharos.xyz` | `https://pharosscan.xyz` | PROS |
| Pharos Atlantic Testnet *(additional)* | `688688` | `https://atlantic.dplabs-internal.com` | `https://testnet.pharosscan.xyz` | PROS |

All onchain actions default to **Pharos Mainnet**. Switch to the testnet by exporting `PHAROS_RPC_URL=https://atlantic.dplabs-internal.com` and `CHAIN_ID=688688` before running any agent command, or by passing `--network testnet` to the CLI scripts.

## Framework

- **Smart contracts** — Solidity `0.8.24`, OpenZeppelin Contracts `v5.x`, Hardhat `2.x`.
- **Agent runtime** — Node.js `>=18`, TypeScript `5.x`, viem `2.x`.
- **Skill format** — `SKILL.md` with YAML frontmatter (`name`, `description`, `license`, `metadata`), Markdown body.
- **Token standard** — ERC-721 + ERC-721URIStorage, with onchain metadata (base64 `data:application/json`).
- **Tooling** — `solhint`, `prettier-plugin-solidity`, `hardhat` test runner, `solidity-coverage`.

## Repository Layout

```
SVGM/
├── skills/
│   └── svgm/
│       └── SKILL.md
├── contracts/
│   ├── OnchainSVG.sol
│   ├── SVGMinter.sol
│   └── interfaces/
│       └── ISVGMinter.sol
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
│           ├── types.ts
│           └── ipfs.ts
├── docs/
│   ├── ARCHITECTURE.md
│   └── SECURITY.md
├── hardhat.config.ts
├── package.json
├── .gitignore
├── LICENSE
└── README.md
```

## Installation

```bash
git clone https://github.com/Yemiight02/SVGM
cd SVGM
npm install
cd agent && npm install && cd ..
cp agent/.env.example agent/.env
# fill in PRIVATE_KEY
```

## Quick Start

### 1. Compile contracts

```bash
npx hardhat compile
```

### 2. Deploy a collection to Pharos Mainnet

```bash
npx hardhat run scripts/deploy.ts --network pharos
```

Or use the viem wrapper directly:

```bash
npx ts-node agent/scripts/deploy-collection.ts \
  --name "Pharos Genesis" \
  --symbol "PHG" \
  --bytecode 0x... \
  --abi-file ./artifacts/contracts/OnchainSVG.sol/OnchainSVG.json
```

### 3. Mint

```bash
# Mint with an existing SVG file
npx ts-node agent/scripts/mint.ts \
  --collection 0xYourCollection \
  --to 0xRecipient \
  --svg-file ./my-art.svg

# Mint with a generated prompt
npx ts-node agent/scripts/mint.ts \
  --collection 0xYourCollection \
  --to 0xRecipient \
  --prompt '{"shapes":["circle","rect"],"palette":["#2F80ED","#0D0D0D"],"seed":42}' \
  --name "Genesis #1" \
  --description "First onchain SVG of the Pharos Genesis collection."
```

### 4. Read a token

```bash
npx ts-node agent/scripts/read-token.ts \
  --collection 0xYourCollection \
  --token-id 1
```

The response includes the onchain `tokenURI`, the decoded metadata JSON, and a `data:image/svg+xml;base64,...` image URI that can be opened directly in any browser.

## Skill Loading

The `skills/svgm/SKILL.md` file is the consumable unit. Any agent runtime that follows the standard skill format (YAML frontmatter + Markdown body) can load it. Key metadata:

```yaml
name: svgm
description: Generate, validate, and mint onchain SVG NFTs on Pharos Network. ...
license: MIT
metadata:
  author: yemiight02
  version: "1.0.0"
  category: onchain-art
  chain: pharos
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

## Security

- The onchain SVG validator strips `<script>` tags, `javascript:` URIs, and `on*=` event-handler attributes. The contract enforces the same restrictions as a second line of defense.
- All mints are `onlyOwner` — the collection deployer is the admin. Agents should disclose ownership to the user before deploying.
- A 24 KB SVG size cap is enforced both client-side and onchain to keep individual mints safely inside Pharos block gas limits.
- Private keys are read from environment variables only. Never commit `.env`.
- See [`docs/SECURITY.md`](docs/SECURITY.md) for the full threat model.

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `PRIVATE_KEY` | yes | — | EOA key (hex, with or without `0x`) used to deploy and mint |
| `PHAROS_RPC_URL` | no | `https://rpc.pharos.xyz` | JSON-RPC endpoint |
| `CHAIN_ID` | no | `1672` | `1672` for mainnet, `688688` for testnet |
| `EXPLORER_URL` | no | `https://pharosscan.xyz` | Used to build transaction links |
| `GAS_LIMIT_BUFFER` | no | `120` | Percent buffer added to `estimateGas` |
| `SVG_MAX_BYTES` | no | `24576` | Reject SVGs larger than this (24 KB) |

## Limitations

- EVM only. No Stylus, no WASM contracts.
- 1-of-1 mints in v1 — no batch minting helper yet.
- The default SVG generator is shape + palette + seed based. Plug a richer generator into `agent/scripts/generate-svg.ts` for trait / parametric output.

## License

MIT — see [`LICENSE`](LICENSE).
