# SVGM on Termux / Android

The SVGM agent runtime is built to be friendly to **Termux on Android**,
which has some unusual constraints:

- **No Python, no NDK, no native build tools** by default.
- **No native npm deps** (e.g. `better-sqlite3`, `sharp`, `bcrypt`) —
  they all fail to compile.
- The runtime uses `viem` (pure JS) and `ts-node` (no native deps).

## Install (Termux)

```bash
pkg update && pkg upgrade
pkg install nodejs-lts git
git clone https://github.com/Yemiight02/SVGM
cd SVGM
cd skills/svgm/scripts
npm install --no-audit --no-fund --omit=optional
```

## Deploy / Mint from Termux

The contract tooling (Foundry) does **not** run on Termux. The
recommended workflow is:

1. Build contracts on a normal Linux/macOS machine (or CI):
   `forge build` → produces `out/OnchainSVG.sol/OnchainSVG.json`
2. Copy `out/` into `skills/svgm/scripts/out/` on the Termux device
3. Run the agent runtime against the pre-built artifact:
   `npx ts-node ./mint.ts --collection 0x… --to 0x… --svg-file ./art.svg`

## Private key handling

**Never paste your private key into a chat window or pasteboard
manager.** On Termux, use `nano` to type it into `.env` directly:

```bash
cd skills/svgm/scripts
nano .env
# PRIVATE_KEY=0x...   ← type this manually, no paste
chmod 600 .env
```

If you've ever pasted a key into chat, **rotate it immediately** at
https://pharosscan.xyz (export a new key from your wallet) and fund
the new address.