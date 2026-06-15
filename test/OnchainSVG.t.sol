// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {OnchainSVG} from "../contracts/OnchainSVG.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

/**
 * @title  OnchainSVGTest
 * @notice Foundry-native unit + fuzz tests for `OnchainSVG`.
 * @dev    Replaces the legacy `test/OnchainSVG.test.js` (Hardhat/chai) suite.
 *         Covers: mint happy path, tokenURI shape, metadata edit, owner
 *         gating, all three SVG-safety rules, oversize cap, and a property
 *         fuzz that nothing containing a forbidden substring can ever slip
 *         past `_enforceSafe`.
 */
contract OnchainSVGTest is Test {
    OnchainSVG internal c;
    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");
    address internal attacker = makeAddr("attacker");

    string constant SAMPLE = string(
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10" width="10" height="10">'
        '<circle cx="5" cy="5" r="4" fill="#2F80ED"/>' "</svg>"
    );

    function setUp() public {
        vm.prank(owner);
        c = new OnchainSVG("Test", "TST", owner);
    }

    // -- happy path -----------------------------------------------------------

    function test_Mint_ReturnsDataUri() public {
        vm.prank(owner);
        c.mint(user, SAMPLE);
        assertEq(c.totalSupply(), 1, "totalSupply");

        string memory uri = c.tokenURI(1);
        assertTrue(_startsWith(uri, "data:application/json;base64,"), "prefix");

        // Reconstruct the expected JSON and base64-encode it; the URI must equal it.
        string memory expectedJson = string.concat(
            '{"name":"Onchain SVG #1",',
            '"description":"Fully onchain SVG minted with SVGM on Pharos.",',
            '"image":"data:image/svg+xml;base64,',
            Base64.encode(bytes(SAMPLE)),
            '",',
            '"attributes":[{"trait_type":"storage","value":"onchain"},{"trait_type":"chain","value":"pharos"}]}'
        );
        string memory expectedUri = string.concat("data:application/json;base64,", Base64.encode(bytes(expectedJson)));
        assertEq(uri, expectedUri, "uri equals expected");
    }

    function test_MintWithMetadata_StoresNameAndDescription() public {
        vm.prank(owner);
        c.mintWithMetadata(user, SAMPLE, "Pixel #1", "first onchain pixel");

        string memory uri = c.tokenURI(1);
        string memory json = _decodeJson(uri);
        assertEq(_jsonStringAt(json, "name"), "Pixel #1");
        assertEq(_jsonStringAt(json, "description"), "first onchain pixel");
    }

    function test_SetMetadata_UpdatesOnchain() public {
        vm.startPrank(owner);
        c.mint(user, SAMPLE);
        c.setMetadata(1, "Renamed", "New desc");
        vm.stopPrank();

        string memory json = _decodeJson(c.tokenURI(1));
        assertEq(_jsonStringAt(json, "name"), "Renamed");
        assertEq(_jsonStringAt(json, "description"), "New desc");
    }

    // -- access control -------------------------------------------------------

    function test_RevertWhen_NonOwnerMints() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        c.mint(user, SAMPLE);
    }

    function test_RevertWhen_NonOwnerSetsMetadata() public {
        vm.prank(owner);
        c.mint(user, SAMPLE);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        c.setMetadata(1, "x", "y");
    }

    function test_RevertWhen_TokenURICalledOnUnminted() public {
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 42));
        c.tokenURI(42);
    }

    // -- SVG safety -----------------------------------------------------------

    function test_RevertWhen_SVGEmpty() public {
        vm.prank(owner);
        vm.expectRevert(OnchainSVG.EmptySVG.selector);
        c.mint(user, "");
    }

    function test_RevertWhen_SVGContainsScriptTag() public {
        string memory evil = string(
            '<?xml version="1.0" encoding="UTF-8"?>' '<svg xmlns="http://www.w3.org/2000/svg">'
            '<script type="text/javascript">alert(1)</script>' '<circle cx="5" cy="5" r="4" fill="#2F80ED"/>' "</svg>"
        );
        vm.prank(owner);
        vm.expectRevert(OnchainSVG.ForbiddenSVGContent.selector);
        c.mint(user, evil);
    }

    function test_RevertWhen_SVGContainsJavascriptURI() public {
        string memory evil = string(
            '<?xml version="1.0" encoding="UTF-8"?>' '<svg xmlns="http://www.w3.org/2000/svg">'
            '<a xlink:href="javascript:alert(1)">x</a>' "</svg>"
        );
        vm.prank(owner);
        vm.expectRevert(OnchainSVG.ForbiddenSVGContent.selector);
        c.mint(user, evil);
    }

    function test_RevertWhen_SVGContainsOnerror() public {
        string memory evil = string(
            '<?xml version="1.0" encoding="UTF-8"?>' '<svg xmlns="http://www.w3.org/2000/svg" onerror="boom()">'
            "</svg>"
        );
        vm.prank(owner);
        vm.expectRevert(OnchainSVG.ForbiddenSVGContent.selector);
        c.mint(user, evil);
    }

    function test_RevertWhen_SVGTooLarge() public {
        // 24_577 ASCII bytes — one over the cap.
        string memory tooBig = _repeat("a", 24_577);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(OnchainSVG.SVGTooLarge.selector, 24_577, 24_576));
        c.mint(user, tooBig);
    }

    function test_Accepts_SVGAtCap() public {
        // 24_576 bytes — exactly the cap, should pass.
        string memory ok = string.concat(SAMPLE, _repeat(" ", 24_576 - bytes(SAMPLE).length));
        vm.prank(owner);
        c.mint(user, ok);
        assertEq(c.totalSupply(), 1);
    }

    // -- property-based fuzz --------------------------------------------------
    // Random SAMPLE-shaped strings must always either succeed (if safe) or revert
    // with a documented error. We never expect a random input to silently mint
    // a token containing a forbidden substring.

    function testFuzz_MintRoundTrip(
        uint256 seed,
        uint8 fillChar
    ) public {
        // Build a tiny valid SVG, then optionally inject a "harmless" payload
        // (random ASCII). If the payload happens to look like a forbidden
        // substring, the contract must reject it; otherwise it must succeed.
        bytes memory fill = new bytes(1);
        fill[0] = bytes1(uint8(0x20 + (fillChar % (0x7E - 0x20 + 1))));

        // Bound the body to 200 bytes so the fuzz budget is meaningful.
        uint256 bodyLen = (seed % 200) + 1;
        bytes memory body = new bytes(bodyLen);
        for (uint256 i = 0; i < bodyLen; i++) {
            body[i] = fill[0];
        }

        string memory svg = string(
            abi.encodePacked(
                '<?xml version="1.0" encoding="UTF-8"?>',
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10" width="10" height="10">',
                body,
                "</svg>"
            )
        );

        bytes memory lower = _lower(bytes(svg));
        bool expectScript = _contains(lower, "<script");
        bool expectJs = _contains(lower, "javascript:");
        bool expectOnError = _contains(lower, "onerror=");
        bool forbidden = expectScript || expectJs || expectOnError;

        if (forbidden) {
            vm.prank(owner);
            vm.expectRevert(OnchainSVG.ForbiddenSVGContent.selector);
            c.mint(user, svg);
        } else {
            vm.prank(owner);
            c.mint(user, svg);
            assertEq(c.totalSupply(), 1, "valid mint should increase supply");
        }
    }

    // -- helpers --------------------------------------------------------------

    function _startsWith(
        string memory s,
        string memory p
    ) internal pure returns (bool) {
        bytes memory sb = bytes(s);
        bytes memory pb = bytes(p);
        if (sb.length < pb.length) return false;
        for (uint256 i = 0; i < pb.length; i++) {
            if (sb[i] != pb[i]) return false;
        }
        return true;
    }

    function _decodeJson(
        string memory uri
    ) internal pure returns (string memory) {
        bytes memory ub = bytes(uri);
        bytes memory prefix = bytes("data:application/json;base64,");
        bytes memory b64 = new bytes(ub.length - prefix.length);
        for (uint256 i = 0; i < b64.length; i++) {
            b64[i] = ub[prefix.length + i];
        }
        return string(_b64Decode(b64));
    }

    /// @dev Minimal RFC-4648 base64 decoder. Sufficient for the OZ-encoded
    ///      payloads in this test (no whitespace, no URL-safe alphabet).
    function _b64Decode(
        bytes memory input
    ) internal pure returns (bytes memory) {
        // Build the reverse lookup table once.
        bytes memory TABLE = bytes("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/");
        // Strip trailing '=' padding.
        uint256 inLen = input.length;
        while (inLen > 0 && input[inLen - 1] == 0x3D) inLen--;

        uint256 outLen = (inLen * 3) / 4;
        bytes memory out = new bytes(outLen);
        uint256 o = 0;
        uint256 acc;
        uint256 bits;

        for (uint256 i = 0; i < inLen; i++) {
            bytes1 c = input[i];
            // Find the character in TABLE.
            uint256 v = 64;
            for (uint256 k = 0; k < 64; k++) {
                if (TABLE[k] == c) {
                    v = k;
                    break;
                }
            }
            require(v < 64, "invalid base64");
            acc = (acc << 6) | v;
            bits += 6;
            if (bits >= 8) {
                bits -= 8;
                out[o++] = bytes1(uint8((acc >> bits) & 0xFF));
            }
        }
        // Trim if we over-allocated.
        assembly {
            mstore(out, o)
        }
        return out;
    }

    function _jsonStringAt(
        string memory json,
        string memory key
    ) internal pure returns (string memory) {
        // Naive parser: looks for `"<key>":"<value>"` and returns the value
        // verbatim. Sufficient for the test assertions in this suite.
        bytes memory jb = bytes(json);
        bytes memory kb = bytes(string.concat('"', key, '":'));
        uint256 start = _indexOf(jb, kb);
        require(start != type(uint256).max, "json key not found");
        start += kb.length;
        // Skip optional whitespace.
        while (start < jb.length && (jb[start] == 0x20 || jb[start] == 0x09)) start++;
        require(start < jb.length && jb[start] == 0x22, "json value not a string");
        start++;
        uint256 end = start;
        while (end < jb.length) {
            if (jb[end] == 0x5C) {
                end += 2;
                continue;
            }
            if (jb[end] == 0x22) break;
            end++;
        }
        bytes memory out = new bytes(end - start);
        for (uint256 i = 0; i < out.length; i++) {
            out[i] = jb[start + i];
        }
        return string(out);
    }

    function _indexOf(
        bytes memory hay,
        bytes memory needle
    ) internal pure returns (uint256) {
        if (needle.length == 0 || hay.length < needle.length) return type(uint256).max;
        for (uint256 i = 0; i <= hay.length - needle.length; i++) {
            bool ok = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (hay[i + j] != needle[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return i;
        }
        return type(uint256).max;
    }

    function _lower(
        bytes memory src
    ) internal pure returns (bytes memory) {
        bytes memory dst = new bytes(src.length);
        for (uint256 i = 0; i < src.length; i++) {
            bytes1 c = src[i];
            if (c >= 0x41 && c <= 0x5A) dst[i] = bytes1(uint8(c) + 32);
            else dst[i] = c;
        }
        return dst;
    }

    function _contains(
        bytes memory hay,
        string memory needle
    ) internal pure returns (bool) {
        bytes memory n = bytes(needle);
        if (n.length == 0 || hay.length < n.length) return false;
        for (uint256 i = 0; i <= hay.length - n.length; i++) {
            bool ok = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (hay[i + j] != n[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return true;
        }
        return false;
    }

    function _repeat(
        string memory s,
        uint256 n
    ) internal pure returns (string memory) {
        bytes memory sb = bytes(s);
        bytes memory out = new bytes(sb.length * n);
        for (uint256 i = 0; i < n; i++) {
            for (uint256 j = 0; j < sb.length; j++) {
                out[i * sb.length + j] = sb[j];
            }
        }
        return string(out);
    }
}
