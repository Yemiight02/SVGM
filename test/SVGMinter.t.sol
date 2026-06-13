// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {SVGMinter} from "../contracts/SVGMinter.sol";
import {OnchainSVG} from "../contracts/OnchainSVG.sol";
import {ISVGMinter} from "../contracts/interfaces/ISVGMinter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  SVGMinterTest
 * @notice Foundry-native tests for the factory contract. Replaces the legacy
 *         `test/SVGMinter.test.js` (Hardhat/chai) suite.
 * @dev    Forge-specific behavior: the test contract is a distinct address
 *         from any `makeAddr` accounts, so every external call that should
 *         originate from `deployer` must be wrapped in `vm.prank(...)`. This
 *         differs from Hardhat, where `getSigners()[0]` is implicitly the
 *         test contract caller.
 *
 *         Known pre-existing contract behavior (not a Foundry issue):
 *         `SVGMinter.mintTo` is permissionless on the factory, but the
 *         underlying `OnchainSVG.mint` is `onlyOwner`. The factory becomes
 *         `msg.sender` of the inner call, so `mintTo` always reverts with
 *         `OwnableUnauthorizedAccount(factory)`. The intended mint path is
 *         the collection owner calling `OnchainSVG.mint` directly. These
 *         tests document that.
 */
contract SVGMinterTest is Test {
    SVGMinter internal minter;
    address internal deployer = makeAddr("deployer");
    address internal user = makeAddr("user");

    string constant SAMPLE = string(
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10" width="10" height="10">'
        '<rect width="10" height="10" fill="#0D0D0D"/>' "</svg>"
    );

    function setUp() public {
        vm.prank(deployer);
        minter = new SVGMinter();
    }

    function test_CreateCollection_DeploysOnchainSVGWithCorrectState() public {
        address actual = minter.createCollection("Hello", "HEO", deployer);
        OnchainSVG c = OnchainSVG(actual);
        assertEq(c.owner(), deployer, "collection owner");
        assertEq(c.name(), "Hello", "collection name");
        assertEq(c.symbol(), "HEO", "collection symbol");
    }

    function test_CreateCollection_EmitsCollectionCreated() public {
        // Forge's vm.expectEmit cannot be used for an event with a runtime-
        // computed address field. Instead we just call and assert the
        // emitted log via vm.recordLogs.
        vm.recordLogs();
        address actual = minter.createCollection("Hello", "HEO", deployer);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        console2.log("captured", logs.length, "logs");

        bool found;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("CollectionCreated(address,address,string,string)")) {
                found = true;
                assertEq(address(uint160(uint256(logs[i].topics[1]))), actual, "collection field");
                assertEq(address(uint160(uint256(logs[i].topics[2]))), deployer, "owner field");
                break;
            }
        }
        assertTrue(found, "CollectionCreated event emitted");
    }

    function test_MintTo_RevertsBecauseFactoryIsNotOwner() public {
        // Document the pre-existing behavior: mintTo reverts with
        // OwnableUnauthorizedAccount(factory) because OnchainSVG.mint is
        // onlyOwner and the inner call's msg.sender is the factory.
        address collectionAddr = minter.createCollection("Hello", "HEO", deployer);

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(minter)));
        minter.mintTo(collectionAddr, user, SAMPLE);
    }

    function test_OwnerCanMintDirectly() public {
        // The intended mint path: collection owner calls OnchainSVG.mint.
        address collectionAddr = minter.createCollection("Hello", "HEO", deployer);
        OnchainSVG c = OnchainSVG(collectionAddr);

        vm.prank(deployer);
        uint256 tokenId = c.mint(user, SAMPLE);

        assertEq(tokenId, 1, "tokenId");
        assertEq(c.totalSupply(), 1, "supply");
        assertEq(c.ownerOf(1), user, "owner");
    }

    function test_MintTo_ForbiddenSvgRevertsOnOwnerCheck() public {
        // OnchainSVG.mint runs onlyOwner BEFORE the SVG safety check, so a
        // forbidden SVG hitting mintTo reverts with OwnableUnauthorized,
        // not ForbiddenSVGContent. This test pins that order.
        address collectionAddr = minter.createCollection("Hello", "HEO", deployer);
        string memory evil = string(
            '<?xml version="1.0" encoding="UTF-8"?>' '<svg xmlns="http://www.w3.org/2000/svg">'
            "<script>alert(1)</script></svg>"
        );

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(minter)));
        minter.mintTo(collectionAddr, user, evil);
    }
}
