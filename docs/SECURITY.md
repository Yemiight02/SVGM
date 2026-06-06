# Security

## Threat Model

SVGM is an onchain SVG NFT skill. The most realistic threats are:

1. **Malicious SVG payloads** — an attacker crafts an SVG that runs JavaScript, drains a wallet, or abuses an XSS sink in a downstream viewer.
2. **Oversize SVGs** — an attacker submits an SVG that would push a single transaction past the block gas limit, effectively bricking the collection.
3. **Unauthorized minting** — an attacker mints to a collection they do not own.
4. **Key leakage** — the deployer's private key is committed to source control or printed in logs.
5. **Chain mismatch** — the agent accidentally signs a transaction on the wrong chain (e.g. mainnet when testnet was intended).

## Mitigations

### Malicious SVG payloads

- The `validate-svg.ts` script rejects SVGs containing `<script>`, `javascript:` URIs, or `on*=` event-handler attributes.
- `OnchainSVG._enforceSafe` enforces the same rules in the contract as defense in depth.
- The onchain sanitizer lowercases the input before substring-matching, so obfuscation (`<SCRIPT>`, `<sCrIpT>`) does not bypass it.

### Oversize SVGs

- A 24 KB cap (`SVG_MAX_BYTES`, default `24576`) is enforced both client-side and onchain.
- Minting SVGs that exceed the cap reverts with `SVGTooLarge(size, max)`.

### Unauthorized minting

- `OnchainSVG.mint` and `OnchainSVG.mintWithMetadata` are `onlyOwner`.
- `agent/scripts/mint.ts` reads `owner()` from the chain before signing and aborts if the caller is not the owner.
- The factory (`SVGMinter`) does not bypass ownership — it simply calls the collection's `mint`, so the collection owner still has to be the transaction signer.

### Key leakage

- Private keys are read from `PRIVATE_KEY` only. The default `.env.example` ships with an empty value.
- `.env` is git-ignored.
- Logs and error messages never print the private key.

### Chain mismatch

- `agent/scripts/lib/pharos.ts` resolves the chain from a typed `PharosNetwork` enum. The default is `"mainnet"`.
- The chain id is part of the typed `Chain` object passed to viem, so signing on the wrong chain is a hard error rather than a silent mistake.

## Out of Scope

- Reentrancy in the mint path — `mint` performs a state change and then an external call to `_safeMint`. `onERC721Received` callbacks from the recipient are out of scope.
- Frontend / wallet integration. SVGM returns data URIs and assumes the caller (marketplace, wallet, agent UI) renders them safely.
- The deterministic SVG generator is for convenience only. Do not mint AI-generated art that the user has not approved.
