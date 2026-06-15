# ============================================================================
# SVGM — Foundry-friendly Makefile
# ----------------------------------------------------------------------------
# This Makefile is the entry point for agents and humans alike. It assumes:
#   - Foundry is installed (https://book.getfoundry.sh/getting-started/installation)
#   - A `.env` file exists with PRIVATE_KEY, PHAROS_RPC_URL, etc.
#   - The OpenZeppelin contracts are already in `lib/` (vendored).
#
# Examples:
#     make build
#     make test
#     make deploy-collection NAME="Pixel Pals" SYMBOL="PPLS"
#     make mint COLLECTION=0xabc... RECIPIENT=0xdef... SVG_FILE=./art.svg
#     make verify COLLECTION=0xabc...
# ============================================================================

# --- Toolchain --------------------------------------------------------------
FORGE       ?= forge
CAST        ?= cast
ANVIL       ?= anvil
PYTHON      ?= python3

# --- Env --------------------------------------------------------------------
# Loads .env (and .env.example as a fallback) so vars are available to recipes.
ifneq (,$(wildcard ./.env))
include .env
export
endif

PHAROS_MAINNET_RPC ?= https://rpc.pharos.xyz
PHAROS_TESTNET_RPC ?= https://atlantic.dplabs-internal.com
CHAIN_ID            ?= 1672
EXPLORER_URL        ?= https://pharosscan.xyz

# --- Default target ---------------------------------------------------------
.PHONY: help
help: ## Show this help (default).
	@awk 'BEGIN {FS = ":.*##"; printf "\nSVGM Foundry targets:\n\n"} \
		/^[a-zA-Z0-9_.-]+:.*##/ { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

# --- Build & test -----------------------------------------------------------
.PHONY: install-libs
install-libs: ## Vendor forge-std + OpenZeppelin contracts into lib/.
	@if [ ! -d lib/forge-std ]; then \
		git clone --depth 1 -b v1.9.6 https://github.com/foundry-rs/forge-std.git lib/forge-std; \
	fi
	@if [ ! -d lib/openzeppelin-contracts ]; then \
		git clone --depth 1 -b v5.0.2 https://github.com/OpenZeppelin/openzeppelin-contracts.git lib/openzeppelin-contracts; \
	fi

.PHONY: build
build: ## Compile all contracts.
	$(FORGE) build

.PHONY: test
test: ## Run the full Foundry test suite.
	$(FORGE) test

.PHONY: test-verbose
test-verbose: ## Run tests with -vvv traces.
	$(FORGE) test -vvv

.PHONY: test-gas
test-gas: ## Run tests with a gas report.
	$(FORGE) test --gas-report

.PHONY: coverage
coverage: ## Run coverage via forge coverage (requires lcov).
	$(FORGE) coverage --report lcov

.PHONY: fmt
fmt: ## Auto-format Solidity.
	$(FORGE) fmt

.PHONY: fmt-check
fmt-check: ## Check formatting (CI-friendly).
	$(FORGE) fmt --check

.PHONY: clean
clean: ## Remove build artifacts.
	$(FORGE) clean
	rm -rf out cache broadcast deployments/local

# --- Local node -------------------------------------------------------------
.PHONY: anvil
anvil: ## Start a local Anvil node (chain id 31337).
	$(ANVIL) --chain-id 31337

# --- Deployment: mainnet (default) ------------------------------------------
.PHONY: deploy-collection
deploy-collection: ## Deploy OnchainSVG to mainnet. NAME and SYMBOL are env vars.
	@test -n "$$PRIVATE_KEY" || (echo "PRIVATE_KEY not set in .env"; exit 1)
	COLLECTION_NAME="$${NAME:-Pharos Genesis}" \
	COLLECTION_SYMBOL="$${SYMBOL:-PHG}" \
	$(FORGE) script script/Deploy.s.sol:DeployCollection \
		--rpc-url $(PHAROS_MAINNET_RPC) \
		--broadcast \
		$${VERIFY:+--verify}

.PHONY: deploy-factory
deploy-factory: ## Deploy SVGMinter factory to mainnet.
	@test -n "$$PRIVATE_KEY" || (echo "PRIVATE_KEY not set in .env"; exit 1)
	$(FORGE) script script/Deploy.s.sol:DeployFactory \
		--rpc-url $(PHAROS_MAINNET_RPC) \
		--broadcast \
		$${VERIFY:+--verify}

# --- Deployment: testnet ----------------------------------------------------
.PHONY: deploy-collection-testnet
deploy-collection-testnet: ## Deploy OnchainSVG to Atlantic testnet.
	@test -n "$$PRIVATE_KEY" || (echo "PRIVATE_KEY not set in .env"; exit 1)
	COLLECTION_NAME="$${NAME:-Pharos Genesis}" \
	COLLECTION_SYMBOL="$${SYMBOL:-PHG}" \
	$(FORGE) script script/Deploy.s.sol:DeployCollection \
		--rpc-url $(PHAROS_TESTNET_RPC) \
		--broadcast

.PHONY: deploy-factory-testnet
deploy-factory-testnet: ## Deploy SVGMinter factory to Atlantic testnet.
	@test -n "$$PRIVATE_KEY" || (echo "PRIVATE_KEY not set in .env"; exit 1)
	$(FORGE) script script/Deploy.s.sol:DeployFactory \
		--rpc-url $(PHAROS_TESTNET_RPC) \
		--broadcast

# --- Minting ----------------------------------------------------------------
.PHONY: mint
mint: ## Mint to an existing collection. Requires COLLECTION, RECIPIENT, and (SVG_FILE or SVG_BODY).
	@test -n "$(COLLECTION)" || (echo "COLLECTION=<addr> required"; exit 1)
	@test -n "$(RECIPIENT)" || (echo "RECIPIENT=<addr> required"; exit 1)
	@test -n "$(SVG_FILE)$(SVG_BODY)" || (echo "SVG_FILE=<path> or SVG_BODY=<svg> required"; exit 1)
	@test -n "$$PRIVATE_KEY" || (echo "PRIVATE_KEY not set in .env"; exit 1)
	$(FORGE) script script/Mint.s.sol:Mint \
		--rpc-url $(PHAROS_MAINNET_RPC) \
		--broadcast

.PHONY: mint-testnet
mint-testnet: ## Mint on Atlantic testnet.
	@test -n "$(COLLECTION)" || (echo "COLLECTION=<addr> required"; exit 1)
	@test -n "$(RECIPIENT)" || (echo "RECIPIENT=<addr> required"; exit 1)
	@test -n "$(SVG_FILE)$(SVG_BODY)" || (echo "SVG_FILE=<path> or SVG_BODY=<svg> required"; exit 1)
	@test -n "$$PRIVATE_KEY" || (echo "PRIVATE_KEY not set in .env"; exit 1)
	$(FORGE) script script/Mint.s.sol:Mint \
		--rpc-url $(PHAROS_TESTNET_RPC) \
		--broadcast

.PHONY: mint-batch
mint-batch: ## Mint a fixed-edition batch of identical NFTs. Needs COLLECTION, RECIPIENT, COUNT, and (SVG_FILE or SVG_BODY).
	@test -n "$(COLLECTION)" || (echo "COLLECTION=<addr> required"; exit 1)
	@test -n "$(RECIPIENT)" || (echo "RECIPIENT=<addr> required"; exit 1)
	@test -n "$(COUNT)" || (echo "COUNT=<n> required (1..50)"; exit 1)
	@test -n "$(SVG_FILE)$(SVG_BODY)" || (echo "SVG_FILE=<path> or SVG_BODY=<svg> required"; exit 1)
	@test -n "$$PRIVATE_KEY" || (echo "PRIVATE_KEY not set in .env"; exit 1)
	$(FORGE) script script/Mint.s.sol:MintBatch \
		--rpc-url $(PHAROS_MAINNET_RPC) \
		--broadcast

.PHONY: mint-batch-testnet
mint-batch-testnet: ## Batch-mint on Atlantic testnet.
	@test -n "$(COLLECTION)" || (echo "COLLECTION=<addr> required"; exit 1)
	@test -n "$(RECIPIENT)" || (echo "RECIPIENT=<addr> required"; exit 1)
	@test -n "$(COUNT)" || (echo "COUNT=<n> required (1..50)"; exit 1)
	@test -n "$(SVG_FILE)$(SVG_BODY)" || (echo "SVG_FILE=<path> or SVG_BODY=<svg> required"; exit 1)
	@test -n "$$PRIVATE_KEY" || (echo "PRIVATE_KEY not set in .env"; exit 1)
	$(FORGE) script script/Mint.s.sol:MintBatch \
		--rpc-url $(PHAROS_TESTNET_RPC) \
		--broadcast

# --- Read a token -----------------------------------------------------------
.PHONY: read
read: ## Read onchain token data. Requires COLLECTION and TOKEN_ID.
	@test -n "$(COLLECTION)" || (echo "COLLECTION=<addr> required"; exit 1)
	@test -n "$(TOKEN_ID)" || (echo "TOKEN_ID=<n> required"; exit 1)
	$(CAST) call $(COLLECTION) "tokenURI(uint256)(string)" $(TOKEN_ID) --rpc-url $(PHAROS_MAINNET_RPC)

# --- Verify on Pharoscan ---------------------------------------------------
.PHONY: verify
verify: ## Verify a deployed contract on Pharoscan. Requires ADDRESS and (CHAIN_ID).
	@test -n "$(ADDRESS)" || (echo "ADDRESS=<addr> required"; exit 1)
	$(FORGE) verify-contract \
		--chain-id $(CHAIN_ID) \
		--etherscan-api-key $${PHAROSCAN_API_KEY:-} \
		--verifier-url $(EXPLORER_URL)/api \
		$(ADDRESS) \
		contracts/OnchainSVG.sol:OnchainSVG
