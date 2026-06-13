# SVGM — Security Model

## Threat Model

| Threat                                            | Mitigation                                                                                                                              |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Malicious SVG content (XSS in wallets/marketplaces) | Two layers: agent-side `validateSVG` rejects `<script>`, `javascript:`, and `on*=`; on-chain `_enforceSafe` rejects `<script>`, `javascript:`, and `onerror=`. |
| SVG storage bloat → out-of-gas mint                | 24 KiB cap enforced in both layers.                                                                                                     |
| Unauthorized mint                                  | `OnchainSVG.mint` / `mintWithMetadata` / `setMetadata` are all `onlyOwner`.                                                            |
| Private key leak via commit                        | `.env` is git-ignored. CI never has access to `PRIVATE_KEY`. Foundry's `forge script` reads it from the env at run time only.          |
| Block-explorer API key leak                        | `PHAROSCAN_API_KEY` is optional and treated as a secret. Never hard-code.                                                              |
| Replay of mint tx on testnet                      | Each tx is freshly signed; the chain id is part of the EIP-155 signature, so a mainnet-signed tx is invalid on testnet and vice versa. |
| Front-running of `createCollection`                | The factory deployment is independent of subsequent mints; front-running the deploy only changes the collection address, not the admin. |
| SVG hash collision                                 | `_hashOf` is non-cryptographic and used only as an event-log fingerprint. The canonical SVG is in the event data, not the hash.        |

## Ownership Disclosure

The `Ownable` admin of each `OnchainSVG` collection is the address passed as the third constructor argument (`collectionOwner`). When an agent deploys a collection:

- If the user supplied `--owner 0x...`, that address is the admin.
- Otherwise the agent's EOA (from `PRIVATE_KEY`) is the admin.

Agents **must disclose this to the user** before deploying. The deploy script logs the admin address to stdout.

## Sanitization Limits

The current `_enforceSafe` is intentionally simple (substring search on lowercased text). It catches the obvious XSS vectors but is **not a general HTML/SVG sanitizer**. If you accept user-supplied SVGs from untrusted sources, run them through a proper sanitizer (e.g. DOMPurify in a sandboxed environment) *before* calling `mint`.

## Reporting

Found a vulnerability? Open a GitHub issue marked `security` or DM the maintainer. Please do not open public PRs with proof-of-concept exploits.
