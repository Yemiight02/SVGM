# SVGM Phase 2 — Termux Setup

This is the **one-shot setup block** to run on your Android/Termux
device. It clones the repo, installs the agent runtime, and smoke-tests
the runtime end-to-end.

## Prerequisites (already done if you've been working on SVGM)

```bash
pkg update && pkg upgrade
pkg install nodejs-lts git unzip
which forge   # if missing: see contracts/INSTALL.md or use a Linux box
```

## SSH first, then repo

**Use SSH, not a PAT.** This avoids leaking tokens in chat.

```bash
# 1. Generate an SSH key if you don't have one
ls ~/.ssh/id_ed25519 2>/dev/null || ssh-keygen -t ed25519 -C "your_email@example.com"

# 2. Add ~/.ssh/id_ed25519.pub to GitHub Settings > SSH keys

# 3. Test the connection
ssh -T git@github.com
```

If `ssh -T git@github.com` returns "Hi Yemiight02! You've successfully
authenticated" you're good. If it asks for a password, the key isn't
installed yet — go to `https://github.com/settings/keys` and paste the
output of `cat ~/.ssh/id_ed25519.pub`.

## Configure git

```bash
git config --global user.name "O.A Dolapo"
git config --global user.email "your_email@example.com"
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

## Full Phase 2 setup (one block)

Paste-and-go:

```bash
WORK="$HOME/svgm-phase2"
mkdir -p "$WORK"
cd "$WORK"

# 1. Clone (uses SSH thanks to the config above)
git clone git@github.com:Yemiight02/SVGM.git repo
cd repo
git log --oneline -3    # should show ~ 131bf35 at HEAD

# 2. Install the agent runtime (no native deps; --omit=optional!)
cd phase2/svgm/scripts
npm install --no-audit --no-fund --omit=optional

# 3. Compile via tsc (verifies the audit fix)
npx tsc -p tsconfig.json
ls dist/

# 4. Smoke-test the runtime (no chain action)
node -e "
const { generateSVG } = require('./dist/generate-svg');
const { validateSVG } = require('./dist/validate-svg');
const { mintSVG, mintBatchSVG, mintBatchDistinctSVG, MAX_BATCH_SIZE } = require('./dist/mint');

const svg = generateSVG({ seed: 7, size: 256 });
console.log('  generateSVG OK — ' + svg.length + ' bytes');

const v = validateSVG(svg);
console.log('  validateSVG OK — errors=' + JSON.stringify(v.errors));

const bad = '<svg xmlns=\"http://www.w3.org/2000/svg\"><script>alert(1)</script></svg>';
const bv = validateSVG(bad);
console.log('  validateSVG rejected malicious SVG — ok=' + bv.ok);

console.log('  mintSVG, mintBatchSVG, mintBatchDistinctSVG all exported');
console.log('  MAX_BATCH_SIZE = ' + MAX_BATCH_SIZE);
"

# 5. Smoke-test the CLI
npx ts-node ./generate-svg.ts --seed 7 --size 256 --out /tmp/svgm-termux-test.svg
npx ts-node ./validate-svg.ts /tmp/svgm-termux-test.svg
ls -la /tmp/svgm-termux-test.svg

# 6. Build the Anvita-Flow-ready zip (top-level `svgm/` folder)
#    We're inside phase2/. Zipping `svgm/` from here gives us
#    exactly the layout Anvita Flow's Skills spec wants — a
#    folder named after the skill at the zip root.
cd ../..
zip -r /tmp/svgm.zip svgm/ \
    -x "*.DS_Store" "*.git/*" \
    "svgm/scripts/node_modules/*" \
    "svgm/scripts/dist/*"
ls -la /tmp/svgm.zip
unzip -l /tmp/svgm.zip | head -3
unzip -l /tmp/svgm.zip | tail -3
echo "  ^ THIS is the file you upload to Anvita Flow Developer Console."

echo ""
echo "✅ SVGM Phase 2 Termux setup complete."
```

## On-chain deploy (testnet) — separate from runtime install

The runtime install above is **off-chain only**. For an actual on-chain
mint you need:

```bash
# 7a. Install Foundry (Termux can compile it but is slow; easier to
#     use a Linux box to build, copy the out/ artifact over)
curl -L https://foundry.paradigm.xyz | bash
foundryup
cd ../..   # back to repo root
forge build
forge test      # expect: 29 tests pass

# 7b. Configure .env (NEVER paste the private key; use `nano`)
cd agent
cp .env.example .env
nano .env
# PRIVATE_KEY=0x...          ← type this manually
# PHAROS_RPC_URL=https://atlantic.dplabs-internal.com
# CHAIN_ID=688688
chmod 600 .env

# 7c. Deploy (needs > 0 PROS on the testnet wallet)
cd ..
forge script script/Deploy.s.sol:DeployCollection \
    --rpc-url https://atlantic.dplabs-internal.com \
    --broadcast
# → prints: collection : 0xNEW_ADDRESS

# 7d. Mint something against the fresh collection
COLLECTION=0xNEW_ADDRESS RECIPIENT=0xYOUR_WALLET \
SVG_FILE=./agent/svgm-test.svg TOKEN_NAME="Genesis #1" \
  forge script script/Mint.s.sol:Mint \
    --rpc-url https://atlantic.dplabs-internal.com \
    --broadcast
# → prints: tokenId : 1
```

## Where to find stuff after install

| Item | Path on Termux |
|------|----------------|
| Repo root | `~/svgm-phase2/repo/` |
| Phase 2 skill | `~/svgm-phase2/repo/phase2/svgm/` |
| Phase 2 zip (upload this) | `/tmp/svgm-phase2.zip` |
| Compiled runtime | `~/svgm-phase2/repo/phase2/svgm/scripts/dist/` |
| Live demo URL (reference) | https://yemiight02.github.io/SVGM/ |
| Anvita Flow Console (upload there) | https://flow.anvita.xyz/service-agents |

## What this script does (in 7 commands)

1. Setup workspace at `~/svgm-phase2/`
2. Clone the repo via SSH (no PAT)
3. Install agent runtime — viem 2.x + ts-node + TypeScript
4. Build to `dist/` via `tsc` (proves the audit fix works)
5. Smoke-test: `generateSVG`, `validateSVG` (positive + malicious), all 3 mint exports
6. CLI smoke: produce a real SVG with `ts-node`, validate it
7. Zip the Phase 2 skill for Anvita Flow Developer Console upload

## What this script does NOT do (intentionally)

- **No private keys anywhere.** `nano .env` later if you need on-chain.
- **No on-chain transactions.** Foundry and a funded wallet are
  separate steps. Until then the static demo at `yemiight02.github.io/SVGM/`
  is the working artifact.
- **No PATs in commands.** SSH keeps secrets out of scrollback.

## Common issues on Termux

| Symptom | Fix |
|---------|-----|
| `npm install` complains about gyp/python | Ensure you ran `npm install --omit=optional` (the skip is critical on Termux) |
| `tsc` not found | `npm install --save-dev typescript` then `npx tsc` |
| `forge: command not found` | Run `foundryup` after `curl -L ... | bash`, then `source ~/.bashrc` |
| `git push` asks for password | SSH key isn't installed — go to github.com/settings/keys |
| `node_modules/.cache` warnings | Safe to ignore; they come from ts-node |
| `cannot read property 'toLowerCase'` on a random RPC error | Means the testnet RPC rejected the request; usually a rate-limit, just retry |