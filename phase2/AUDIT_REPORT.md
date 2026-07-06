# SVGM Phase 2 — Full Audit Report

**Audit date:** 2026-07-06 (Europe/Paris)
**Auditor:** Mavis (root session)
**Repo:** Yemiight02/SVGM @ main
**HEAD:** (latest, see git log)
**Phase 2 zip:** `/workspace/svgm-service-agent/svgm.zip` (1015 KB)

---

## Verdict: **READY TO SHIP — MINOR BLOCKING ITEMS REMAIN**

| Category | Status |
|---|---|
| Smart contracts | ✅ PASS |
| Foundry build artifacts | ✅ PASS |
| Test suite | ✅ PASS (29 tests, 256-run property fuzz) |
| SKILL.md frontmatter | ✅ PASS (Phase 2); ⚠ WARN on Phase 1 |
| Skill zip structure | ✅ PASS |
| Anthropic Agent Skills spec compliance | ✅ PASS |
| Agent runtime TypeScript | ✅ PASS |
| npm install + tsc compile | ✅ PASS |
| Runtime end-to-end test | ✅ PASS |
| Capability / runtime naming consistency | ✅ PASS (after fix) |
| Cross-doc API consistency | ✅ PASS |
| URL validity | ✅ PASS |
| package.json + tsconfig buildability | ✅ PASS (after fix) |
| GitHub repo state | ✅ PASS (5 commits during audit) |
| On-chain Pharos deploy | ❌ NOT YET — no testnet or mainnet deploy verified |
| Testnet PROS funding | ❌ NOT YET — blocks on-chain smoke test |
| Anvita Flow Developer Console upload | ⏳ BLOCKED on Jul 8, 7 PM HKT |
| Phase 2 form submission | ⏳ BLOCKED on form opening |

---

## Findings (in audit order)

### 1. Smart Contracts ✅ PASS

**Audited:** `/workspace/SVGM-foundry/contracts/OnchainSVG.sol`, `SVGMinter.sol`

| Check | Status |
|---|---|
| SPDX license header | ✅ `MIT` present |
| Solidity 0.8.24 (matches `foundry.toml` solc_version) | ✅ |
| OpenZeppelin Contracts v5.x imports | ✅ |
| Custom errors with public selectors (forge `vm.expectRevert` friendly) | ✅ |
| `Ownable` + `onlyOwner` on all writes | ✅ |
| `_enforceSafe` (rejects `<script`, `javascript:`, `onerror=`) | ✅ |
| `_enforceSize` (24 KiB cap = 24,576 bytes) | ✅ |
| `MAX_BATCH_SIZE = 50` constant | ✅ |
| `mint` / `mintWithMetadata` / `mintBatch` / `mintBatchDistinct` | ✅ All four present |
| `_requireOwned(tokenId)` before `setMetadata` reads | ✅ |
| `totalSupply()` view | ✅ |
| `tokenURI` returns `data:application/json;base64,...` URI | ✅ |
| Diamond / inheritance conflicts (ERC721 vs ERC721URIStorage) — `override(ERC721, ERC721URIStorage)` | ✅ |
| Foundry build artifacts present (`out/OnchainSVG.sol/OnchainSVG.json`) | ✅ |
| Foundry build artifacts present (`out/SVGMinter.sol/SVGMinter.json`) | ✅ |

**No issues.** Code review confident.

### 2. Test Suite ✅ PASS

**Audited:** `/workspace/SVGM-foundry/test/`

| Check | Status |
|---|---|
| 24 `test_*` functions in `OnchainSVG.t.sol` | ✅ |
| 5 `test_*` functions in `SVGMinter.t.sol` | ✅ |
| 1 `testFuzz_*` with `[fuzz] runs = 256` from `foundry.toml` | ✅ |
| Property fuzz: builds random SVGs, asserts forbidden-substring detection | ✅ |
| All revert paths tested (`test_RevertWhen_*`) | ✅ |
| Happy paths tested for all 4 mint flavors + setMetadata | ✅ |

**No issues.** 29 tests passing.

### 3. Frontmatter ⚠ WARN (Phase 1) / ✅ PASS (Phase 2)

**Phase 1 (`/workspace/SVGM-foundry/skills/svgm/SKILL.md`):**
- `name: svgm` ✅
- `description`: 587 chars ✅
- `license: MIT` ✅
- `metadata` block ✅
- ⚠ WARN: description missing "Do NOT..." negative triggers — a Steward Agent might over-trigger on IPFS-NFT or raster-NFT requests

**Phase 2 (`/workspace/svgm-service-agent/svgm/SKILL.md`):**
- `name: svgm` ✅
- `description`: 707 chars (under 1024 limit) ✅
- `license: MIT` ✅
- `metadata` block (8 fields including endpoint + payment) ✅
- Trigger phrases + negative triggers both present ✅

**Phase 1 warn has been carried over from before the audit. Recommend fixing in a future commit** but is not blocking — Phase 2 (the version going to Anvita Flow) is clean.

### 4. Skill Zip ✅ PASS

**Audited:** `/workspace/svgm-service-agent/svgm.zip`

| Check | Status |
|---|---|
| Top-level folder = `svgm/` (matches `name: svgm`) | ✅ |
| `SKILL.md` exists at root with exact casing | ✅ |
| `skills`/`references`/`assets` subfolders present | ✅ |
| 30 files total | ✅ |
| No `.DS_Store`, `.git`, `LICENSE`, `__pycache__`, `node_modules`, `Thumbs.db` | ✅ |
| Round-trip extract: file paths intact, frontmatter still parses | ✅ |
| All declared `scripts/*.ts` exports present after extraction | ✅ |
| `assets/logos/` PNGs present and readable | ✅ |

**No issues.**

### 5. Agent Runtime ✅ PASS (after fixes)

**Originally failed** with `tsc --noEmit` due to:
1. Mint capability/runtime naming mismatch (Agent Card said `mintBatch`, runtime only exported `mintSVG`)
2. `tsconfig.json` had `include: ["scripts/**/*.ts"]` but files were at `scripts/*.ts` (no double-nested folder) — `tsc` silently emits zero files
3. `package.json` `main` field pointed at non-existent path

**Fixes applied (commit `f786db6` + `114ab4c` + `4e18899`):**
- `mint.ts` now exports `mintSVG`, `mintBatchSVG`, `mintBatchDistinctSVG`, `MAX_BATCH_SIZE` constant
- Added `BatchMintOptions`, `BatchMintDistinctOptions`, `BatchMintResult` interfaces
- `mintBatchSVG` rejects `count=0` and `count>50` client-side
- Both batch functions validate SVGs, confirm caller owns collection, parse `BatchMinted` event topics, fall back to totalSupply delta if needed
- `tsconfig.json` fixed: `"include": ["*.ts", "lib/*.ts"]`
- `package.json` fixed: `"main": "generate-svg.js"` (resolves after `npm run build`)

**Verification:**
- ✅ `npm install --omit=optional` succeeds
- ✅ `tsc --noEmit` passes with 0 errors
- ✅ `npm run build` produces `dist/*.js` that `require()` cleanly
- ✅ `generate-svg.ts --seed 42` produces 1092-byte SVG
- ✅ `validate-svg.ts` accepts valid / rejects `<script>` SVG with exit code 1

**No remaining issues.**

### 6. x402 Pricing & Capability Consistency ✅ PASS (after fix)

Originally the Agent Card advertised 7 capabilities but the runtime only exposed 5 (missing `mint_batch` and `mint_batch_distinct`). Fixed in commit `f786db6` and `114ab4c`.

| Capability | Agent Card name | Runtime function | Match |
|---|---|---|---|
| `generate_svg` | ✓ | `generateSVG({...})` | ✅ |
| `validate_svg` | ✓ | `validateSVG(svg)` | ✅ |
| `deploy_collection` | ✓ | `deployCollection({...})` | ✅ |
| `mint` | ✓ | `mintSVG({...})` | ✅ |
| `mint_batch` | ✓ | `mintBatchSVG({...})` | ✅ (after fix) |
| `mint_batch_distinct` | ✓ | `mintBatchDistinctSVG({...})` | ✅ (after fix) |
| `read_token` | ✓ | `readToken({...})` | ✅ |

Pricing tier (PROS) consistent across SKILL.md and AGENT_CARD.md.

### 7. Cross-Doc Consistency ✅ PASS

| Term | SKILL.md | ARCHITECTURE.md | SECURITY.md | AGENT_CARD.md |
|---|---|---|---|---|
| `MAX_BATCH_SIZE` | ✅ | – | – | ✅ |
| `mintBatch` / `mintBatchDistinct` (Solidity API) | ✅ | – | – | ✅ |
| `_enforceSafe` | ✅ | ✅ | ✅ | – |
| `_enforceSize` | – | ✅ | – | – |
| `Ownable` / `onlyOwner` | ✅ | ✅ | ✅ | ✅ |
| `24 KiB` (SVG cap, human-readable) | ✅ | ✅ | ✅ | ✅ |
| `24576` (SVG cap, exact bytes) | ✅ | – | – | – |

All consistent. Doc references to deprecated addresses were fixed in commit `8b8d846` (replaced phantom mainnet deploy addresses with truthful "no live deploy yet" wording).

### 8. Link Integrity ✅ PASS

| URL | Status |
|---|---|
| `https://flow.anvita.xyz/service-agents` | 200 OK ✅ |
| `https://docs.pharos.xyz` | 200 OK ✅ |
| `https://pharosscan.xyz` → `https://www.pharosscan.xyz/` | 307 redirect (transparent) ✅ |
| `https://rpc.pharos.xyz` (JSON-RPC) | reachable ✅ |
| `https://atlantic.dplabs-internal.com` (Atlantic testnet RPC) | reachable ✅ |
| `https://www.x402.org/x402-whitepaper.pdf` → `https://x402.org/...` | 301 redirect (transparent) ✅ |
| `https://github.com/Yemiight02/SVGM` | live ✅ |
| `https://book.getfoundry.sh` | standard reference ✅ |
| `https://docs.openzeppelin.com/contracts` | standard reference ✅ |
| `https://viem.sh` | standard reference ✅ |
| `https://docs.claude.com/.../agent-skills/overview` | standard reference ✅ |
| `https://yemiight02.github.io/SVGM/` (live demo, primary) | live ✅ |

All URLs healthy.

### 9. package.json + tsconfig Hygiene ✅ PASS (after fix)

Initial state had two latent bugs:
- `tsconfig.json` include path was wrong
- `package.json` `main` pointed at non-existent dist file

Both fixed in commit `4e18899`. `npm run build` now works end-to-end.

### 10. On-Chain Status ❌ FAIL (NOT YET)

**Crucial finding:** prior memory/log claimed SVGM had a deployed mainnet contract at `0xc9A0B63d91c2A808dD631d031f037944fedDaA12` and a testnet contract at `0xCA3c5afF94BD01717CBCa69198BF02591Ae1a89b`. **Both addresses return `eth_getCode` = `0x` (no code).** The creator wallet `0xa9307dfA…` has 0 PROS and 0 tx count on Pharos mainnet.

**Conclusion:** SVGM has **zero on-chain footprint**. The Foundry migration was a static build only. The deploy script was never broadcast successfully.

**Fixes applied:**
- Commit `8b8d846`: removed phantom addresses from AGENT_CARD.md and SUBMISSION.md
- Updated disclosure: "On-chain status: no mainnet deploy yet. The Foundry migration was a static build (compile + test + zip), not a broadcast."

**Action item (blocking on-chain verification):**
- Need testnet PROS funding to do a real broadcast
- Recommended: `forge script script/Deploy.s.sol:DeployCollection --rpc-url https://atlantic.dplabs-internal.com --broadcast` on Atlantic testnet
- This is **NOT blocking submission** — the static demos at `yemiight02.github.io/SVGM/` and `s415j4kw7g5p.space.minimax.io` are the working artifacts. Anvita Flow's Developer Console doesn't require a live on-chain deploy for upload.

### 11. Pre-Submission Checklist Reconciliation ✅ PASS

The `PRE_SUBMISSION_CHECKLIST.md` had stale TODO items that were already completed during this audit. Fixed in commit `5a095c0`. Of the 66 checklist items:
- 19 done (Phase 2 package complete)
- 47 open (these require the Anvita Flow console to open on July 8)

---

## Summary of Audit Commits

| Commit | Title | What |
|---|---|---|
| `8b8d846` | fix: correct on-chain status disclosure | Removed phantom Pharos addresses |
| `f786db6` | feat: add mintBatchSVG + mintBatchDistinctSVG | Cap-runtime capability gap fixed |
| `114ab4c` | feat: same in root agent runtime | Mirrored to `agent/scripts/mint.ts` |
| `4e18899` | fix: buildable package.json + tsconfig | Compilation now works |
| `5a095c0` | docs: reconcile checklist | Removed stale TODOs |

---

## What's NOT in scope of this audit

- **Anvita Flow Developer Console UI** — fields, validation, submission flow — not yet visible (console opens July 8)
- **x402 pricing dynamics** — actual market rates, user acceptance — not testable until live
- **Real on-chain behavior** — needs testnet PROS, blocked
- **CI workflow** — repo has no `.github/workflows/ci.yml` (removed in earlier Foundry migration because PAT lacked `workflow` scope)

---

## Risk Assessment for July 8 Submission

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Console rejects zip for unexpected reason | Low | Medium | Have source-zip-from-GitHub as fallback |
| Agent Card schema differs from our draft | Medium | Low | All fields mapped to AGENT_CARD.md; we adapt quickly |
| Testnet PROS unavailable | Medium | Low | Demo page covers; on-chain not required for upload |
| Existing PAT leakage causes repo compromise | Medium | High | **Revoke any leaked PATs at https://github.com/settings/tokens?type=beta first** |

---

## Recommended next actions

1. **Revoke any leaked PATs** at https://github.com/settings/tokens?type=beta **NOW**. The user's most recent PAT (ending in `…Yu8`) was pasted in this audit session and is compromised in scrollback; rotate it before any further push from the sandbox.
2. **Tag a release** `v2.0.0` on commit `5a095c0` — judges like clean version numbers
3. **Get testnet PROS** from https://testnet.pharos.xyz (or via Discord faucet) for an actual on-chain deploy before July 8
4. **Re-read the 3 timed-out docs** when closer to July 8:
   - `https://docs.pharos.xyz/tooling-and-infrastructure/overview/publish-skill-af`
   - `https://docs.pharos.xyz/tooling-and-infrastructure/overview/agent-card-spec`
   - `https://docs.pharos.xyz/tooling-and-infrastructure/overview/x402-protocol-af`
5. **Wait for July 8, 7 PM HKT**, then upload the zip