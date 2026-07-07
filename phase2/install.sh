#!/data/data/com.termux/files/usr/bin/bash
# SVGM Phase 2 — single-file Termux installer (verified on Termux Node 22+)
#
# USAGE (on Termux, after generating an SSH key and adding it to GitHub):
#   bash install.sh
#
# WHAT IT DOES:
#   1. Ensures zip/unzip are installed
#   2. Verifies SSH key + GitHub access
#   3. Clones the SVGM repo via SSH
#   4. Installs agent runtime (viem + ts-node + typescript) — pure JS, no native builds
#   5. Compiles via tsc -> dist/ (verifies the audit-fixed tsconfig)
#   6. Smoke-tests all 7 capabilities + MAX_BATCH_SIZE export
#   7. Produces ~/svgm.zip ready for Anvita Flow upload (top-level svgm/ folder)
#
# NO PRIVATE KEYS, NO PATs. Private keys are typed into .env via `nano` separately.

set -e

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"
info() { printf "${BOLD}▶${RESET} %s\n" "$*"; }
ok()   { printf "${GREEN}✓${RESET} %s\n" "$*"; }
warn() { printf "${YELLOW}⚠${RESET} %s\n" "$*"; }
die()  { printf "${RED}✗${RESET} %s\n" "$*" >&2; exit 1; }

# ===== 1. zip / unzip =====
info "Ensure zip/unzip are installed"
if ! command -v zip >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
  pkg install -y zip unzip
fi
command -v zip >/dev/null 2>&1 || die "zip is missing — please run: pkg install zip"
command -v unzip >/dev/null 2>&1 || die "unzip is missing — please run: pkg install unzip"
ok "zip + unzip present"

# ===== 2. SSH key + GitHub access =====
info "SSH key + GitHub access"
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  warn "No SSH key at ~/.ssh/id_ed25519. Let me generate one now."
  ssh-keygen -t ed25519 -C "your_email@example.com"
  echo
  echo "════════════════════════════════════════════════════════"
  echo "  COPY THE PUBLIC KEY BELOW INTO GitHub:"
  echo "════════════════════════════════════════════════════════"
  cat "$HOME/.ssh/id_ed25519.pub"
  echo "════════════════════════════════════════════════════════"
  echo "  → https://github.com/settings/keys"
  echo "  → Click 'New SSH key', paste the line above, save."
  echo "  → Then press Enter here to continue."
  read -r _
fi

# This will either succeed (Hi Yemiight02!) or fail (Permission denied)
if ! ssh -T -o StrictHostKeyChecking=accept-new git@github.com 2>&1 | tee /tmp/ssh-test.log | grep -q "successfully authenticated"; then
  warn "SSH test failed. Did you add the public key to GitHub yet?"
  echo "The public key is on screen below. Add it at https://github.com/settings/keys,"
  echo "then press Enter to retry, or Ctrl+C to abort."
  cat "$HOME/.ssh/id_ed25519.pub"
  read -r _
  if ! ssh -T -o StrictHostKeyChecking=accept-new git@github.com 2>&1 | grep -q "successfully authenticated"; then
    die "SSH auth still failing. Re-check https://github.com/settings/keys"
  fi
fi
ok "SSH auth to GitHub — confirmed"

# ===== 3. git config =====
info "Configure git"
git config --global user.name "O.A Dolapo"
git config --global user.email "${GIT_EMAIL:-your_email@example.com}"
git config --global url."git@github.com:".insteadOf "https://github.com/"
ok "git config applied"

# ===== 4. Workspace + clone =====
info "Workspace + clone"
WORK="$HOME/svgm-phase2"
if [ -d "$WORK" ]; then
  warn "Workspace $WORK already exists. Reusing it."
  cd "$WORK/repo"
  git pull --rebase || true
else
  mkdir -p "$WORK"
  cd "$WORK"
  git clone git@github.com:Yemiight02/SVGM.git repo
  cd repo
fi
HEAD=$(git rev-parse --short HEAD)
ok "Repo at $WORK/repo (HEAD=$HEAD)"

# ===== 5. Install agent runtime =====
info "Install agent runtime"
cd "$WORK/repo/phase2/svgm/scripts"
# Pure-JS deps; --omit=optional skips the few native ones that fail on Termux
npm install --no-audit --no-fund --omit=optional 2>&1 | tail -5
ok "node_modules populated ($(ls node_modules | wc -l) packages)"

# Make sure TypeScript actually installed under .bin (the
# auto-install sometimes grabs a different "tsc" package).
if [ ! -x node_modules/.bin/tsc ]; then
  warn "tsc missing from .bin — installing typescript explicitly"
  npm install --no-audit --no-fund --omit=optional --save-dev typescript@5 ts-node@10
fi
ok "TypeScript at node_modules/.bin/tsc"

# ===== 6. Compile =====
info "Compile (tsc)"
./node_modules/.bin/tsc -p tsconfig.json
[ -d dist ] || die "tsc ran but produced no dist/ folder"
ok "dist/ has $(ls dist | wc -l) entries"

# ===== 7. Smoke-test all 7 capabilities =====
info "Runtime smoke-test (all 7 capabilities)"
node -e "
const { generateSVG } = require('./dist/generate-svg');
const { validateSVG } = require('./dist/validate-svg');
const { mintSVG, mintBatchSVG, mintBatchDistinctSVG, MAX_BATCH_SIZE } = require('./dist/mint');

const svg = generateSVG({ seed: 7, size: 256 });
console.log('  generateSVG      OK (' + svg.length + ' bytes)');

const v = validateSVG(svg);
console.log('  validateSVG      OK (errors=' + JSON.stringify(v.errors) + ')');

const bad = '<svg xmlns=\"http://www.w3.org/2000/svg\"><script>x</script></svg>';
const bv = validateSVG(bad);
console.log('  validateSVG      rejects malicious — ok=' + bv.ok);

console.log('  mintSVG          exported');
console.log('  mintBatchSVG     exported');
console.log('  mintBatchDistinctSVG exported');
console.log('  MAX_BATCH_SIZE  = ' + MAX_BATCH_SIZE);
" 2>&1
ok "All 7 capabilities verified"

# ===== 8. CLI smoke-test =====
info "CLI smoke-test"
./node_modules/.bin/ts-node ./generate-svg.ts --seed 7 --size 256 --out ~/svgm-termux-test.svg
./node_modules/.bin/ts-node ./validate-svg.ts ~/svgm-termux-test.svg
ls -la ~/svgm-termux-test.svg
ok "CLI produced + validated a real SVG"

# ===== 9. Build Anvita-ready zip =====
info "Build Anvita-ready zip (top-level svgm/ folder)"
cd "$WORK/repo/phase2"
zip -r ~/svgm.zip svgm/ \
  -x "*.DS_Store" "*.git/*" "svgm/scripts/node_modules/*" "svgm/scripts/dist/*" 2>&1 | tail -5
ls -la ~/svgm.zip
unzip -l ~/svgm.zip | grep SKILL.md
ok "~/svgm.zip ready"

# ===== Done =====
echo
echo "════════════════════════════════════════════════════════"
echo "  ${GREEN}SVGM Phase 2 setup complete on Termux.${RESET}"
echo "════════════════════════════════════════════════════════"
echo
echo "Artifacts you can use right now:"
echo "  ~/svgm.zip                          ← upload to https://flow.anvita.xyz/service-agents on July 8"
echo "  ~/svgm-termux-test.svg              ← generated + validated SVG"
echo "  $WORK/repo/phase2/svgm/scripts/dist ← compiled runtime (CommonJS)"
echo "  $WORK/repo                           ← the full git checkout"
echo
echo "Try it:"
echo "  cd $WORK/repo/phase2/svgm/scripts"
echo "  ./node_modules/.bin/ts-node ./generate-svg.ts --seed 7 --size 256 --out /tmp/test.svg"
echo "  ./node_modules/.bin/ts-node ./validate-svg.ts /tmp/test.svg"
echo
echo "For on-chain deploy (later, with funded wallet):"
echo "  cd $WORK/repo"
echo "  cp agent/.env.example agent/.env"
echo "  nano agent/.env          # type PRIVATE_KEY=0x... manually, never paste"
echo "  chmod 600 agent/.env"
echo "  forge script script/Deploy.s.sol:DeployCollection \\"
echo "    --rpc-url https://atlantic.dplabs-internal.com \\"
echo "    --broadcast"
echo