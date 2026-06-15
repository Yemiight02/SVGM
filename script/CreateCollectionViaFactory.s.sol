// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ISVGMinter} from "../contracts/interfaces/ISVGMinter.sol";
import {OnchainSVG} from "../contracts/OnchainSVG.sol";

/**
 * @title  CreateCollectionViaFactory
 * @notice Drives a deployed `SVGMinter` factory to spin up a new collection,
 *         then optionally mints a first token to it.
 *
 * @dev    Env vars:
 *           FACTORY          — address of the deployed SVGMinter
 *           COLLECTION_NAME  — string
 *           COLLECTION_SYMBOL — string
 *           COLLECTION_OWNER — address that will own admin rights on the new
 *                              collection (defaults to the broadcaster)
 *           RECIPIENT        — optional, if set mints an initial token
 *           SVG_FILE         — path to SVG for the initial mint
 *           SVG_BODY         — inline SVG for the initial mint (wins over SVG_FILE)
 *           TOKEN_NAME       — optional
 *           TOKEN_DESC       — optional
 */
contract CreateCollectionViaFactory is Script {
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

    function run() external returns (address collection) {
        address factory = vm.envAddress("FACTORY");
        string memory name = vm.envString("COLLECTION_NAME");
        string memory symbol = vm.envString("COLLECTION_SYMBOL");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address operator = vm.addr(pk);

        address owner;
        try vm.envAddress("COLLECTION_OWNER") returns (address o) {
            owner = o;
        } catch {
            owner = operator;
        }

        ISVGMinter minter = ISVGMinter(factory);
        vm.startBroadcast(pk);
        collection = minter.createCollection(name, symbol, owner);
        vm.stopBroadcast();

        console2.log("===========================================");
        console2.log("Factory created collection");
        console2.log("  factory    :", factory);
        console2.log("  collection :", collection);
        console2.log("  owner      :", owner);
        console2.log("  name       :", name);
        console2.log("  symbol     :", symbol);
        console2.log("===========================================");

        // Optional: mint an initial token if RECIPIENT + (SVG_FILE or SVG_BODY) are set.
        try vm.envAddress("RECIPIENT") returns (address recipient) {
            string memory svg = _loadSvg();
            if (bytes(svg).length > 0) {
                string memory tname = _envOr("TOKEN_NAME", "");
                string memory tdesc = _envOr("TOKEN_DESC", "");

                vm.startBroadcast(pk);
                uint256 tokenId = bytes(tname).length == 0
                    ? minter.mintTo(collection, recipient, svg)
                    : _mintWithMeta(minter, collection, recipient, svg, tname, tdesc);
                vm.stopBroadcast();

                console2.log("Initial mint:");
                console2.log("  recipient :", recipient);
                console2.log("  tokenId   :", tokenId);
            }
        } catch {}
    }

    function _mintWithMeta(
        ISVGMinter minter,
        address collection,
        address to,
        string memory svg,
        string memory name,
        string memory desc
    ) internal returns (uint256) {
        // Drive the underlying OnchainSVG directly so we can pass name+desc.
        // The factory's mintTo only forwards (collection, to, svg).
        OnchainSVG c = OnchainSVG(collection);
        return c.mintWithMetadata(to, svg, name, desc);
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
}
