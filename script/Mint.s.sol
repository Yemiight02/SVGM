// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {OnchainSVG} from "../contracts/OnchainSVG.sol";

/**
 * @title  Mint
 * @notice Foundry mint script. Sends a `mintWithMetadata` (or `mint`) call to
 *         a deployed `OnchainSVG` collection. All inputs come from env, so an
 *         agent can drive it without editing code.
 * @dev    Required env: COLLECTION, RECIPIENT, (SVG_FILE or SVG_BODY).
 *         Optional env: TOKEN_NAME, TOKEN_DESC.
 *
 *         Run with:
 *             COLLECTION=0xabc... RECIPIENT=0xdef... SVG_FILE=./art.svg \
 *               TOKEN_NAME="Gen #1" \
 *               forge script script/Mint.s.sol --rpc-url $PHAROS_RPC_URL --broadcast
 */
contract Mint is Script {
    function _envOr(
        string memory key,
        string memory defaultValue
    ) internal view returns (string memory) {
        try vm.envString(key) returns (string memory v) {
            if (bytes(v).length == 0) return defaultValue;
            return v;
        } catch {
            return defaultValue;
        }
    }

    function run() external {
        address collection = vm.envAddress("COLLECTION");
        address recipient = vm.envAddress("RECIPIENT");
        string memory svg = _loadSvg();
        string memory name = _envOr("TOKEN_NAME", "");
        string memory desc = _envOr("TOKEN_DESC", "");

        if (bytes(svg).length == 0) {
            revert("Mint: SVG_FILE or SVG_BODY must be set");
        }
        if (bytes(svg).length > 24_576) {
            revert("Mint: SVG exceeds 24 KiB cap");
        }

        OnchainSVG c = OnchainSVG(collection);
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address operator = vm.addr(pk);

        // Sanity check: only the owner can mint.
        (bool ok, bytes memory data) = collection.staticcall(abi.encodeWithSignature("owner()"));
        require(ok && data.length == 32, "Mint: owner() call failed");
        address owner = abi.decode(data, (address));
        require(operator == owner, "Mint: PRIVATE_KEY does not own the collection");

        vm.startBroadcast(pk);
        uint256 tokenId =
            bytes(name).length == 0 ? c.mint(recipient, svg) : c.mintWithMetadata(recipient, svg, name, desc);
        vm.stopBroadcast();

        console2.log("===========================================");
        console2.log("Minted");
        console2.log("  collection :", collection);
        console2.log("  recipient  :", recipient);
        console2.log("  tokenId    :", tokenId);
        console2.log("  bytes      :", bytes(svg).length);
        console2.log("===========================================");
    }

    function _loadSvg() internal view returns (string memory) {
        // SVG_BODY wins if set.
        try vm.envString("SVG_BODY") returns (string memory body) {
            if (bytes(body).length > 0) return body;
        } catch {}

        // Otherwise read from SVG_FILE.
        try vm.envString("SVG_FILE") returns (string memory path) {
            if (bytes(path).length == 0) return "";
            return vm.readFile(path);
        } catch {
            return "";
        }
    }
}

/**
 * @title  MintBatch
 * @notice Mints a fixed-edition batch of identical NFTs to a single recipient.
 *         Reads `COLLECTION`, `RECIPIENT`, `COUNT`, and (SVG_FILE or SVG_BODY)
 *         from env. For distinct SVGs per token, use `MintBatchDistinct` below.
 * @dev    Run with:
 *             COLLECTION=0xabc... RECIPIENT=0xdef... COUNT=10 SVG_FILE=./art.svg \
 *               forge script script/Mint.s.sol:MintBatch \
 *                 --rpc-url $PHAROS_RPC_URL --broadcast
 */
contract MintBatch is Script {
    function _envOr(
        string memory key,
        string memory defaultValue
    ) internal view returns (string memory) {
        try vm.envString(key) returns (string memory v) {
            if (bytes(v).length == 0) return defaultValue;
            return v;
        } catch {
            return defaultValue;
        }
    }

    function _loadSvg() internal view returns (string memory) {
        try vm.envString("SVG_BODY") returns (string memory body) {
            if (bytes(body).length > 0) return body;
        } catch {}
        try vm.envString("SVG_FILE") returns (string memory path) {
            if (bytes(path).length == 0) return "";
            return vm.readFile(path);
        } catch {
            return "";
        }
    }

    function run() external {
        address collection = vm.envAddress("COLLECTION");
        address recipient = vm.envAddress("RECIPIENT");
        uint256 count = vm.envUint("COUNT");
        string memory svg = _loadSvg();

        if (bytes(svg).length == 0) revert("MintBatch: SVG_FILE or SVG_BODY must be set");
        if (bytes(svg).length > 24_576) revert("MintBatch: SVG exceeds 24 KiB cap");

        OnchainSVG c = OnchainSVG(collection);
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address operator = vm.addr(pk);

        (bool ok, bytes memory data) = collection.staticcall(abi.encodeWithSignature("owner()"));
        require(ok && data.length == 32, "MintBatch: owner() call failed");
        address owner = abi.decode(data, (address));
        require(operator == owner, "MintBatch: PRIVATE_KEY does not own the collection");

        vm.startBroadcast(pk);
        (uint256 fromId, uint256 toId) = c.mintBatch(recipient, svg, count);
        vm.stopBroadcast();

        console2.log("===========================================");
        console2.log("Batch minted");
        console2.log("  collection :", collection);
        console2.log("  recipient  :", recipient);
        console2.log("  count      :", count);
        console2.log("  fromTokenId:", fromId);
        console2.log("  toTokenId  :", toId);
        console2.log("  bytes/svg  :", bytes(svg).length);
        console2.log("===========================================");
    }
}
