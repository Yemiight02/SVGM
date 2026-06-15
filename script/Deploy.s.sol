// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {OnchainSVG} from "../contracts/OnchainSVG.sol";
import {SVGMinter} from "../contracts/SVGMinter.sol";

/// @notice Shared base for SVGM deployment scripts.
abstract contract SVGMScript is Script {
    /// @dev Reads `key` from env, falling back to `defaultValue` if unset/empty.
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
}

/**
 * @title  DeployCollection
 * @notice Deploys a new `OnchainSVG` collection. Reads COLLECTION_NAME /
 *         COLLECTION_SYMBOL from env (defaults: "Pharos Genesis" / "PHG").
 * @dev    Run with:
 *             COLLECTION_NAME="Pixel Pals" COLLECTION_SYMBOL="PPLS" \
 *               forge script script/Deploy.s.sol:DeployCollection \
 *                 --rpc-url $PHAROS_RPC_URL --broadcast --verify
 */
contract DeployCollection is SVGMScript {
    function run() external returns (OnchainSVG collection) {
        string memory name = _envOr("COLLECTION_NAME", "Pharos Genesis");
        string memory symbol = _envOr("COLLECTION_SYMBOL", "PHG");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);

        vm.startBroadcast(pk);
        collection = new OnchainSVG(name, symbol, owner);
        vm.stopBroadcast();

        console2.log("===========================================");
        console2.log("OnchainSVG deployed");
        console2.log("  name       :", name);
        console2.log("  symbol     :", symbol);
        console2.log("  owner      :", owner);
        console2.log("  collection :", address(collection));
        console2.log("===========================================");
    }
}

/**
 * @title  DeployFactory
 * @notice Deploys the `SVGMinter` factory. Use this if you want an agent to
 *         spin up fresh collections on the fly via `createCollection(...)`.
 * @dev    Run with:
 *             forge script script/Deploy.s.sol:DeployFactory \
 *               --rpc-url $PHAROS_RPC_URL --broadcast
 */
contract DeployFactory is SVGMScript {
    function run() external returns (SVGMinter minter) {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        minter = new SVGMinter();
        vm.stopBroadcast();

        console2.log("===========================================");
        console2.log("SVGMinter (factory) deployed");
        console2.log("  factory :", address(minter));
        console2.log("===========================================");
    }
}
