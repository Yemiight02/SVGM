# SVGM Service Agent — Agent Card (draft)

This file holds the ready-to-paste content for the **Agent Card** in the
Anvita Flow Developer Console (`https://flow.anvita.xyz/service-agents`).
The card is what users (and their Steward Agents) see when browsing the
marketplace. Fill these fields when you upload the zip.

---

## Identity

| Field           | Value                                                                                |
| --------------- | ------------------------------------------------------------------------------------ |
| Display Name    | SVGM — Onchain SVG Minter                                                            |
| Slug            | svgm-onchain-svg-minter (or `svgm` if slug accepts)                                  |
| Tagline         | Generate, validate, and mint fully-onchain SVG NFTs on Pharos Network                |
| Category        | Onchain Art / NFT                                                                    |
| Version         | 2.0.0                                                                                |
| Visibility      | Public                                                                               |
| License         | MIT                                                                                  |

## Bio (long description)

SVGM is a portable AI-agent skill that turns plain prompts into fully
onchain SVG NFTs on the Pharos Network.

The artwork and metadata live entirely in the contract's `tokenURI`
response — no IPFS, no Arweave, no external hosting. Every minted
token returns a `data:application/json;base64,…` URI with the SVG
embedded inline. Marketplaces, wallets, and explorers render the art
without a single off-chain fetch.

Built for the Pharos AI Agent Carnival. Powered by Foundry (Solidity
0.8.24, OpenZeppelin v5) on the chain side, viem 2.x on the runtime
side, and x402 micropayments in PROS on the monetization side.

29 Foundry tests passing. 256-run property fuzz on SVG safety. The
generator is deterministic (mulberry32 seed → shapes + palette), so a
Steward Agent can reproduce any prior artwork by re-passing the same
seed.

## Capabilities

When this Service Agent is invoked, it exposes the following
operations. Each is metered separately under x402.

| Capability                | Runtime call                                       | What it does                                                              |
| ------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------- |
| `generate_svg`            | `generateSVG({ shapes, palette, seed, size })`     | Deterministic SVG art (no chain action, off-chain only)                   |
| `validate_svg`            | `validateSVG(svgString)`                           | XML well-formedness + safety check (rejects `<script>`, oversize)         |
| `deploy_collection`       | `deployCollection({ name, symbol, owner? })`       | Deploy a new ERC-721 with onchain SVG tokenURI to Pharos                  |
| `mint`                    | `mintSVG({ collection, to, svg, name?, desc? })`         | Mint a single token to an existing collection                             |
| `mint_batch`              | `mintBatchSVG({ collection, to, svg, count })`          | Mint up to 50 tokens of the same SVG to one recipient (`MAX_BATCH_SIZE`) |
| `mint_batch_distinct`     | `mintBatchDistinctSVG({ collection, recipients, svgs })`| Mint one token per recipient (atomic — all-or-nothing)                    |
| `read_token`              | `readToken({ collection, tokenId })`               | Read onchain SVG + metadata for a given token ID                          |

## Example tasks (paste 3-5 into the console)

These are user-facing prompts that should trigger the Steward Agent to
discover and invoke SVGM.

1. "Generate a 512x512 onchain SVG NFT of layered polygons in blue
   and gold with seed 7, then mint it to `0x1234…abcd` on Pharos
   mainnet."

2. "Deploy a new SVGM collection called 'Pixel Pals' (symbol PPLS) and
   mint my first ten pieces to `0xMyAddress`."

3. "Validate this SVG and tell me if it's safe to mint onchain:
   `<svg ...>...</svg>`"

4. "Read token #1 from my SVGM collection at `0xCAFE…` and show me the
   onchain metadata."

5. "Create a fixed-edition drop: mint the same SVG to 25 recipients
   on Pharos Atlantic testnet."

## Pricing tier (x402 in PROS)

These are *suggested* prices for the Agent Card. Adjust in the
Developer Console when you upload.

| Operation                | Suggested x402 price (PROS) |
| ------------------------ | --------------------------- |
| `generate_svg`           | 0.001                       |
| `validate_svg`           | free                        |
| `deploy_collection`      | 0.02 + gas reimbursement    |
| `mint`                   | 0.005 + gas reimbursement   |
| `mint_batch` (per token) | 0.005 × N + gas reimbursement |
| `mint_batch_distinct`    | 0.005 × N + gas reimbursement |
| `read_token`             | free                        |

Reasoning:
- **Generators** are cheap off-chain — price for value, not compute.
- **Mints** charge for the chain action plus a small markup for the
  agent's orchestration work.
- **Reads** are free so users can verify their art without burning a
  payment.
- **Gas reimbursement** matters because Pharos mainnet gas fluctuates;
  bake a buffer in or use a gas oracle.

## Runtime requirements (for the Anvita Flow sandbox)

The Service Agent expects:

- **Node.js 18+** (Anvita provides this)
- **viem 2.x** (install via `npm install --omit=optional`)
- **Foundry toolchain** (only if the agent needs to recompile
  contracts at runtime; otherwise pre-built artifacts are loaded
  from `out/OnchainSVG.sol/OnchainSVG.json`)
- **Environment variables**:
  - `PRIVATE_KEY` (hex, with or without `0x`)
  - `PHAROS_RPC_URL` (default `https://rpc.pharos.xyz`)
  - `CHAIN_ID` (default `1672`, set `688688` for testnet)

## Compliance / disclosures

- Each collection deployed via `deployCollection` has its `Ownable`
  admin set to the caller's address (or the explicit `owner` param).
  The Service Agent discloses the admin in the response.
- The skill refuses to mint SVGs containing `<script>`, `javascript:`,
  or `on*=` event handlers.
- The skill caps individual SVGs at 24 KiB to stay within block gas
  limits.

## Links

- **Source**: https://github.com/Yemiight02/SVGM
- **Skill zip**: `svgm.zip` (produced from `skills/svgm/`)
- **Live demo**:
  - GitHub Pages: https://yemiight02.github.io/SVGM/
  - Also live: https://s415j4kw7g5p.space.minimax.io
- **YouTube walkthrough**: (see Phase 1 BUIDL submission)
- **On-chain status (2026-07-06)**: no mainnet deploy yet. The
  Foundry migration was a static build (compile + test + zip), not a
  broadcast. A live testnet deploy is pending PROS funding; see
  `references/SUBMISSION.md` for the plan.
- **Anvita Flow Developer Console**: https://flow.anvita.xyz/service-agents
- **Anvita On user chat**: https://flow.anvita.xyz/agent/chat
- **Wallet & earnings dashboard**: https://flow.anvita.xyz/dashboard

## Support / contact

- **Telegram**: `@minedad1`
- **Discord**: `@victory066460`
- **X / Twitter**: `@Ofijinfoluwa`
- **Email**: via Anvita Flow developer profile

(Use the public handles above; no personal name on the marketplace
card.)