# SVGM Phase 2 — Pre-Submission Checklist

Use this when the Anvita Flow Developer Console opens on **July 8, 7 PM
HKT**. Walk through each item before clicking Submit.

## A. Skill zip (this we have)

- [x] `svgm/` folder at top level (name matches frontmatter)
- [x] `SKILL.md` with exact casing at root of `svgm/`
- [x] Frontmatter `name: svgm` (kebab-case, ≤64 chars)
- [x] Frontmatter `description` ≤1024 chars (we have 707)
- [x] Frontmatter `license: MIT`
- [x] Frontmatter `metadata` block (author, version, category, chain, toolchain, runtime, payment, endpoint)
- [x] Trigger phrases in `description` ("Use when...")
- [x] Negative triggers in `description` ("Do NOT use...")
- [x] `scripts/` folder with Node.js runtime (viem)
- [x] `scripts/package.json` with `npm install --omit=optional` working
- [x] `references/` folder with ARCHITECTURE.md, SECURITY.md, TERMUX.md, SUBMISSION.md
- [x] `assets/` folder with logos + sample SVGs
- [x] No `.DS_Store`, `.git`, `LICENSE`, `__pycache__` inside
- [x] `svgm.zip` produced (1014 KB, 31 files)
- [x] Round-trip verified: extracted, frontmatter parses, exports present

## B. Developer Console upload

When the upload UI is open at `https://flow.anvita.xyz/service-agents`:

- [ ] Upload `svgm.zip` (the file at `/workspace/svgm-service-agent/svgm.zip`)
- [ ] Confirm the console correctly identified `name: svgm`, `version: 2.0.0`, `license: MIT`
- [ ] Confirm the description preview shows the full 707-char trigger description
- [ ] If the console asks for runtime config, select **Node.js** and the path to `scripts/`

## C. Agent Card fields

All values are pre-drafted in `AGENT_CARD.md`. Copy from there.

- [ ] Display name: `SVGM — Onchain SVG Minter`
- [ ] Slug: `svgm` (or whatever the console accepts)
- [ ] Tagline: `Generate, validate, and mint fully-onchain SVG NFTs on Pharos Network`
- [ ] Category: `Onchain Art / NFT`
- [ ] Version: `2.0.0`
- [ ] License: `MIT`
- [ ] Bio: full text from `AGENT_CARD.md` § Bio
- [ ] Capabilities list: all 7 capabilities
- [ ] Example tasks: copy all 5 examples from `AGENT_CARD.md`
- [ ] Pricing tier: see table in `AGENT_CARD.md` (start with the suggested values; iterate after first week of usage)
- [ ] Runtime requirements: Node 18+, viem 2.x
- [ ] Required env vars: `PRIVATE_KEY`, `PHAROS_RPC_URL`, `CHAIN_ID`
- [ ] Source link: `https://github.com/Yemiight02/SVGM`
- [ ] Demo link: `https://cyphza0y83hv.space.minimax.io`

## D. x402 pricing configuration

- [ ] Pricing tier set in PROS (not USDC — PROS gets the 20% discount)
- [ ] Free operations marked: `validate_svg`, `read_token`
- [ ] Paid operations priced: `generate_svg`, `deploy_collection`, `mint`, `mint_batch`, `mint_batch_distinct`
- [ ] Gas reimbursement policy: choose between (a) bake gas into the price, (b) charge user separately via x402
- [ ] Test a single paid call from a test Steward Agent wallet before going live

## E. End-to-end test

Before publishing to the marketplace:

- [ ] `generate_svg({ seed: 7 })` returns a valid SVG
- [ ] `validate_svg` rejects a malicious SVG (e.g. one with `<script>`)
- [ ] `deploy_collection` against Atlantic testnet (chain 688688) succeeds
- [ ] `mint` against the freshly deployed testnet collection succeeds
- [ ] `read_token` returns the SVG inline as a `data:` URI
- [ ] x402 charges the test wallet in PROS
- [ ] Pharoscan link in the response resolves to a real tx

## F. Publish & submit

- [ ] Click "Publish" in the Developer Console
- [ ] Note the published Agent URL (e.g. `https://flow.anvita.xyz/agent/svgm`)
- [ ] Submit the Phase 2 form (URL TBA, opens July 8) with:
  - GitHub: `https://github.com/Yemiight02/SVGM`
  - YouTube demo: (paste your video URL)
  - Anvita Agent URL: (the URL from the previous step)
- [ ] Save the submission confirmation email / screenshot

## G. After publish

- [ ] Set up wallet at `https://flow.anvita.xyz/dashboard`
- [ ] Monitor first few x402 charges to confirm payment flow works
- [ ] Update pricing if calls are too expensive or too cheap
- [ ] Reply to any Steward Agent feedback in the marketplace reviews

## H. Things to verify closer to July 8

- [ ] Re-read `https://docs.pharos.xyz/tooling-and-infrastructure/overview/publish-skill-af` for any new fields
- [ ] Re-read `https://docs.pharos.xyz/tooling-and-infrastructure/overview/agent-card-spec` for the exact Agent Card schema
- [ ] Re-read `https://docs.pharos.xyz/tooling-and-infrastructure/overview/x402-protocol-af` for any pricing rules
- [ ] Confirm the Phase 2 form URL (separate from the upload)
- [ ] Confirm the wallet setup flow at `https://flow.anvita.xyz/dashboard`

## I. Repo hygiene (do this now)

- [x] Foundry toolchain, 29 tests passing
- [x] SKILL.md frontmatter valid (YAML, name + description + license)
- [x] Live demo page
- [x] YouTube video URL ready
- [ ] Push the Phase 2 SKILL.md update to GitHub main (commit `phase2-skill-zip`)
- [ ] Add `phase2-skill-zip` tag pointing at the Phase 2 submission
- [ ] Consider also pushing the `svgm.zip` artifact as a GitHub Release
- [ ] Add a `phase2/` folder in the repo with the same content as `svgm/` for transparency (optional but nice for judges)

## J. Critical don'ts

- **Don't** paste private keys anywhere in this conversation or in the
  Anvita console. Use `.env` and `nano`.
- **Don't** mention DonYemiight or any personal name in the Agent Card,
  SKILL.md, or Phase 2 form. Refer as "the developer" or skip.
- **Don't** upload the zip before July 8, 7 PM HKT — payment module is
  still being rolled out.
- **Don't** set prices in USDC — PROS gets the 20% discount and is the
  native currency.
- **Don't** skip the testnet deploy step — even if mainnet works, you
  want a known-good testnet run before publishing.