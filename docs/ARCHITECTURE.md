# SVGM — Architecture

## Toolchain

SVGM is a **Foundry-first** project. All contract compilation, testing, and deployment is done with the Foundry toolchain:

| Task                | Command                                                                                |
| ------------------- | -------------------------------------------------------------------------------------- |
| Install deps        | `make install-libs` (or `forge install`)                                               |
| Compile             | `forge build`                                                                          |
| Test                | `forge test`                                                                           |
| Format              | `forge fmt`                                                                            |
| Coverage            | `forge coverage` (requires `lcov`)                                                     |
| Deploy collection   | `forge script script/Deploy.s.sol:DeployCollection --rpc-url … --broadcast`            |
| Deploy factory      | `forge script script/Deploy.s.sol:DeployFactory --rpc-url … --broadcast`               |
| Mint                | `forge script script/Mint.s.sol:Mint --rpc-url … --broadcast` (env-driven)             |
| Create via factory  | `forge script script/CreateCollectionViaFactory.s.sol --rpc-url … --broadcast`         |
| Local node          | `anvil --chain-id 31337`                                                               |
| Read contract       | `cast call 0x... "tokenURI(uint256)(string)" 1 --rpc-url …`                            |
| Verify              | `forge verify-contract --chain-id 1672 --verifier-url https://pharosscan.xyz/api …`     |

The agent runtime (`agent/`) is a thin Node.js wrapper around `viem`. It reads bytecode and ABI from Foundry's `out/OnchainSVG.sol/OnchainSVG.json` via `agent/scripts/lib/foundry-artifact.ts`, so no Hardhat or other build orchestrator is required.

## Component Diagram

```
                   ┌─────────────────────────────┐
                   │   agent/ (Node + viem)      │
                   │  - generate-svg.ts          │
                   │  - validate-svg.ts          │
                   │  - deploy-collection.ts ───►│ reads out/OnchainSVG.sol/
                   │  - mint.ts                  │      OnchainSVG.json
                   │  - read-token.ts            │
                   └────────────┬────────────────┘
                                │ viem JSON-RPC
                                ▼
   ┌─────────────────────────────────────────────────────┐
   │                  Pharos Network                      │
   │  ┌──────────────┐         ┌──────────────────────┐  │
   │  │  SVGMinter   │──creates─►     OnchainSVG      │  │
   │  │  (factory)   │         │  (ERC-721)           │  │
   │  └──────────────┘         │   - mint             │  │
   │                            │   - mintWithMetadata │  │
   │                            │   - setMetadata      │  │
   │                            │   - tokenURI         │  │
   │                            │   - totalSupply      │  │
   │                            └──────────────────────┘  │
   └─────────────────────────────────────────────────────┘

   Build pipeline (Foundry):
   ┌─────────────┐    ┌──────────────┐    ┌───────────────┐
   │ .sol source │───►│  forge build │───►│  out/*.json   │
   │  contracts/ │    │  (solc 0.8.24│    │  (bytecode +  │
   │  script/    │    │   via_ir,    │    │   abi)        │
   │  test/      │    │   200 runs)  │    └───────────────┘
   └─────────────┘    └──────────────┘           │
                                                ▼
                                       agent runtime picks up
                                       out/OnchainSVG.sol/OnchainSVG.json
```

## Storage Layout (OnchainSVG)

```
mapping(uint256 => TokenData) _tokens
  TokenData { string svg, string name, string description }

_nextTokenId  // starts at 1; totalSupply() = _nextTokenId - 1
```

`tokenURI(tokenId)` builds the metadata JSON inline (no on-chain string concatenation in storage) and returns `data:application/json;base64,…` with the SVG embedded as `image`. The `image` field is itself a `data:image/svg+xml;base64,…` URI, so consumers never need to fetch anything off-chain.

## Security Boundaries

- **`onlyOwner` on all writes** — `mint`, `mintWithMetadata`, `setMetadata`. The deployer of each collection is its admin. The factory `SVGMinter.createCollection` takes a `collectionOwner` parameter so the admin can be the agent's EOA, not the factory.
- **SVG sanitization** — `_enforceSafe` runs lowercase substring checks for `<script`, `javascript:`, and `onerror=`. The agent-side `validateSVG` runs the same checks (and adds `on*=` for any event handler). Belt-and-suspenders.
- **Size cap** — 24 KiB enforced both off-chain (`SVG_MAX_BYTES` env) and on-chain (`_enforceSize`). Keeps `tokenURI` output well under the typical Pharos block gas limit.
- **Private keys** — read from env, never from disk, never committed. `.env` is in `.gitignore`.
