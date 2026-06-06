# Architecture

## Onchain Layer

```
┌─────────────────────────────────────────────────────────────┐
│  OnchainSVG (ERC-721 + URIStorage)                         │
│  ┌─────────────────────────┐  ┌──────────────────────────┐  │
│  │ TokenData { svg, name,  │  │ tokenURI()              │  │
│  │              description}│  │ → base64 data: JSON     │  │
│  └─────────────────────────┘  └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                ▲                                ▲
                │ mint / mintWithMetadata        │ tokenURI / ownerOf / totalSupply
                │                                │
┌─────────────────────────────────────────────────────────────┐
│  SVGMinter (Factory)                                        │
│  createCollection(name, symbol, owner)  → OnchainSVG       │
│  mintTo(collection, to, svg)             → OnchainSVG.mint  │
└─────────────────────────────────────────────────────────────┘
```

- **`OnchainSVG`** stores the raw SVG, optional name, and optional description for every token. `tokenURI` assembles a JSON document (`name`, `description`, `image`, `attributes`) with the SVG base64-embedded, and returns a `data:application/json;base64,...` URI.
- **`SVGMinter`** is an optional factory that lets an agent deploy a fresh `OnchainSVG` in a single `sendTransaction` and then mint to it.
- All storage is onchain. No token, metadata, or image data is ever stored on IPFS, Arweave, or any external host.

## Agent Layer

```
┌─────────────────────┐   ┌────────────────────┐   ┌────────────────────┐
│ generate-svg.ts     │ → │ validate-svg.ts    │ → │ mint.ts / deploy-  │
│ (deterministic)     │   │ (size + safety)    │   │ collection.ts      │
└─────────────────────┘   └────────────────────┘   └────────────────────┘
                                                           │
                                                           ▼
                                                  ┌────────────────────┐
                                                  │ read-token.ts      │
                                                  │ (decode tokenURI)  │
                                                  └────────────────────┘
```

- The agent scripts are stateless. Each one reads its inputs from CLI args or environment, performs one action, and writes JSON to stdout.
- `lib/pharos.ts` holds the chain config (mainnet + testnet) and constructs viem `PublicClient` / `WalletClient` instances.
- The skill is consumed by reading `skills/svgm/SKILL.md`. The YAML frontmatter is parsed once for routing; the Markdown body is loaded only when the skill is activated.

## Network

The primary network is **Pharos Mainnet** (chain id `1672`, RPC `https://rpc.pharos.xyz`). A **Pharos Atlantic Testnet** (chain id `688688`, RPC `https://atlantic.dplabs-internal.com`) is also supported for pre-production testing. There is no other network target.
