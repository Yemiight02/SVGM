# SVGM — Assets

This folder ships with the SVGM skill so a Service Agent (or a human
reviewer) can quickly see what the system produces.

## logos/

| File                       | Size           | Purpose                                                    |
| -------------------------- | -------------- | ---------------------------------------------------------- |
| `svgm-logo-480.png`        | 480×480, 62 KB | Primary logo for hackathon submissions, marketplace cards  |
| `svgm-mark.png`            | ~600×600, 168 KB | Wordmark variant                                          |
| `svgm-avatar.png`          | 800×800, 763 KB | Avatar / profile picture                                   |

## samples/

| File                          | Notes                                                     |
| ----------------------------- | --------------------------------------------------------- |
| `sample-seed-7.svg`           | Generated via `mulberry32(seed=7)`, 11 elements, palette 1|
| `sample-seed-42.svg`          | Generated via `mulberry32(seed=42)`, 8 elements, palette 2|

These samples are **deterministic** — running `npx ts-node ./generate-svg.ts
--seed 7` from the `scripts/` folder will produce byte-identical output.

## Regenerating

```bash
cd ../scripts
npx ts-node ./generate-svg.ts --seed 7   --out ../assets/samples/sample-seed-7.svg
npx ts-node ./generate-svg.ts --seed 42  --out ../assets/samples/sample-seed-42.svg
```

The full Foundry-built tokenURIs (base64-encoded JSON + embedded SVG)
can be read from any deployed collection via:

```bash
cast call 0xYourCollection "tokenURI(uint256)(string)" 1 --rpc-url $PHAROS_RPC_URL
```