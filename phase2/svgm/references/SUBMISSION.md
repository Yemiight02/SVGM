# SVGM — Skill Submission

## Hackathon

**Pharos Agent Carnival** (a.k.a. **Skill-to-Agent Dual Cascade
Hackathon**)

- **Phase 1 (Skills)**: submission via DoraHacks BUIDL
- **Phase 2 (Service Agents)**: Skill uploaded to Anvita Flow Developer
  Console, wrapped as a Service Agent, published to the marketplace

## Identity

- **BUIDL name**: SVGM — Onchain SVG Minter
- **Repo**: https://github.com/Yemiight02/SVGM
- **License**: MIT
- **Chain**: Pharos Network (chain 1672) + Atlantic Testnet (688688)

## Skill spec compliance

- **Format**: Anthropic Agent Skills spec (`SKILL.md` + YAML frontmatter)
- **Folder layout**:
  ```
  svgm/
  ├── SKILL.md            ← required, exact casing
  ├── scripts/            ← Node.js runtime (viem)
  ├── references/         ← ARCHITECTURE, SECURITY, TERMUX, this file
  └── assets/             ← logo, sample SVGs
  ```
- **Frontmatter**:
  - `name: svgm` (kebab-case, matches folder name)
  - `description` (≤1024 chars, includes trigger phrases)
  - `license: MIT`
  - `metadata`: author, version, category, chain, toolchain, payment
- **Zip**: `svgm.zip` containing the `svgm/` folder (NOT a zip of
  `SKILL.md` alone — that's the common mistake)

## Service Agent card (Phase 2)

| Field             | Value                                                                                                  |
| ----------------- | ------------------------------------------------------------------------------------------------------ |
| Name              | SVGM — Onchain SVG Minter                                                                              |
| Category          | Onchain Art / NFT                                                                                      |
| Pricing tier      | Pay-per-call in PROS via x402 (see SKILL.md §x402 Payment)                                             |
| Supported chains  | Pharos mainnet (1672), Pharos Atlantic testnet (688688)                                                |
| Required env vars | `PRIVATE_KEY`, `PHAROS_RPC_URL` (defaults set in SKILL.md)                                             |
| Runtime deps      | Node 18+, viem 2.x, Foundry (only for contract source build; runtime reads pre-built artifacts)        |

## Phase 1 deliverables (already shipped)

- [x] Repo with Foundry toolchain, 29 tests passing
- [x] Live demo page (HTML+JS, deterministic SVG generator)
- [x] YouTube demo video
- [x] SVGM logo assets (480×480 PNG, etc.)
- [x] BUIDL form submitted via DoraHacks

## Phase 2 deliverables (in progress)

- [x] `SKILL.md` for Anthropic-spec compliance (this skill)
- [x] Agent runtime bundled into `scripts/` (viem-based)
- [x] `references/` docs (ARCHITECTURE, SECURITY, TERMUX)
- [x] `assets/` (logos, sample SVGs)
- [ ] `svgm.zip` produced and uploaded to Anvita Flow Developer Console
- [ ] Service Agent Card filled out in console
- [ ] Pricing tier set (x402 PROS)
- [ ] End-to-end test via Anvita On user chat
- [ ] Phase 2 form submitted (GitHub URL + YouTube URL + Agent URL)

## Reproducing the build

```bash
git clone https://github.com/Yemiight02/SVGM
cd SVGM
forge build
forge test                 # expect: 29 tests passing
cd skills/svgm/scripts
npm install --no-audit --no-fund --omit=optional
```

## Live artifacts

| Artifact               | URL                                                          |
| ---------------------- | ------------------------------------------------------------ |
| Demo pages             | https://yemiight02.github.io/SVGM/ (GitHub Pages, primary)
|                        | https://s415j4kw7g5p.space.minimax.io (also live)            |
| On-chain status         | No live deploy on Pharos yet (Foundry build only). Testnet deploy pending PROS funding. |
| YouTube demo           | (uploaded; see Phase 1 BUIDL submission)                     |
| Anvita Flow console    | https://flow.anvita.xyz/service-agents                       |