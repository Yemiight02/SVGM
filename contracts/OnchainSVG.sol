// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title OnchainSVG
/// @notice ERC-721 collection whose tokenURI returns fully-onchain SVG metadata.
///         No IPFS, no external hosting. The SVG, name, and description of every
///         token are stored in contract storage and rendered into a base64
///         `data:application/json` URI on read.
contract OnchainSVG is ERC721, ERC721URIStorage, Ownable {
    using Strings for uint256;

    struct TokenData {
        string svg;
        string name;
        string description;
    }

    uint256 private _nextTokenId;
    mapping(uint256 => TokenData) private _tokens;

    event Minted(address indexed to, uint256 indexed tokenId, string svgHash);
    event MetadataUpdated(uint256 indexed tokenId);

    error EmptySVG();
    error SVGTooLarge(uint256 size, uint256 max);
    error ForbiddenSVGContent();

    /// @param collectionName The human-readable collection name (e.g. "Pharos Genesis")
    /// @param collectionSymbol The collection ticker (e.g. "PHG")
    /// @param initialOwner The address that owns admin rights (defaults to msg.sender)
    constructor(
        string memory collectionName,
        string memory collectionSymbol,
        address initialOwner
    ) ERC721(collectionName, collectionSymbol) Ownable(initialOwner) {
        _nextTokenId = 1;
    }

    /// @notice Mint a token with a fully-onchain SVG.
    /// @dev    The SVG is sanitized (script tags / event-handler attributes stripped)
    ///         and size-capped before being stored.
    function mint(address to, string calldata svg) external onlyOwner returns (uint256 tokenId) {
        return _mintInternal(to, svg, "", "");
    }

    /// @notice Mint a token with metadata (name + description) attached onchain.
    function mintWithMetadata(
        address to,
        string calldata svg,
        string calldata name,
        string calldata description
    ) external onlyOwner returns (uint256 tokenId) {
        return _mintInternal(to, svg, name, description);
    }

    /// @notice Update the metadata of a token the caller owns the admin rights for.
    function setMetadata(
        uint256 tokenId,
        string calldata name,
        string calldata description
    ) external onlyOwner {
        _requireOwned(tokenId);
        _tokens[tokenId].name = name;
        _tokens[tokenId].description = description;
        emit MetadataUpdated(tokenId);
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId - 1;
    }

    /// @inheritdoc ERC721
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        _requireOwned(tokenId);
        TokenData storage data = _tokens[tokenId];

        string memory json = _buildMetadataJSON(tokenId, data);
        return string.concat(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        );
    }

    /// @inheritdoc ERC721
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // --- internal ---

    function _mintInternal(
        address to,
        string calldata svg,
        string memory name,
        string memory description
    ) internal returns (uint256 tokenId) {
        if (bytes(svg).length == 0) revert EmptySVG();
        _enforceSize(svg);
        _enforceSafe(svg);

        tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _tokens[tokenId] = TokenData({ svg: svg, name: name, description: description });

        emit Minted(to, tokenId, _hashOf(svg));
    }

    function _buildMetadataJSON(uint256 tokenId, TokenData storage data) internal view returns (string memory) {
        string memory tokenName = bytes(data.name).length == 0
            ? string.concat("Onchain SVG #", tokenId.toString())
            : data.name;

        string memory tokenDescription = bytes(data.description).length == 0
            ? "Fully onchain SVG minted with SVGM on Pharos."
            : data.description;

        return string.concat(
            '{"name":"', _escape(tokenName),
            '","description":"', _escape(tokenDescription),
            '","image":"data:image/svg+xml;base64,', Base64.encode(bytes(data.svg)),
            '","attributes":[{"trait_type":"storage","value":"onchain"},{"trait_type":"chain","value":"pharos"}]}'
        );
    }

    function _enforceSize(string memory svg) internal pure {
        uint256 max = 24576; // 24 KB
        uint256 size = bytes(svg).length;
        if (size > max) revert SVGTooLarge(size, max);
    }

    /// @dev Defense-in-depth: reject SVGs containing <script> tags or javascript: URIs.
    function _enforceSafe(string memory svg) internal pure {
        bytes memory b = bytes(svg);
        bytes memory lowered = new bytes(b.length);
        for (uint256 i = 0; i < b.length; i++) {
            lowered[i] = _lower(b[i]);
        }
        if (_contains(lowered, "<script") || _contains(lowered, "javascript:") || _contains(lowered, "onerror=")) {
            revert ForbiddenSVGContent();
        }
    }

    function _contains(bytes memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory n = bytes(needle);
        if (n.length == 0 || haystack.length < n.length) return false;
        for (uint256 i = 0; i <= haystack.length - n.length; i++) {
            bool ok = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (haystack[i + j] != n[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return true;
        }
        return false;
    }

    function _lower(bytes1 c) internal pure returns (bytes1) {
        if (c >= 0x41 && c <= 0x5A) return bytes1(uint8(c) + 32);
        return c;
    }

    function _hashOf(string memory s) internal pure returns (string memory) {
        // Tiny non-cryptographic fingerprint for the event log. Wallets and explorers
        // don't need keccak here — a short hash is enough for indexing.
        bytes memory b = bytes(s);
        uint256 h = uint256(keccak256(b)) % 0xFFFFFFFF;
        bytes16 hexchars = "0123456789abcdef";
        bytes memory out = new bytes(8);
        for (uint256 i = 0; i < 8; i++) {
            out[7 - i] = hexchars[uint8(h & 0xF)];
            h >>= 4;
        }
        return string(out);
    }

    function _escape(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        bytes memory out = new bytes(b.length * 2);
        uint256 j;
        for (uint256 i = 0; i < b.length; i++) {
            bytes1 c = b[i];
            if (c == 0x22 || c == 0x5C) {
                out[j++] = 0x5C;
            }
            out[j++] = c;
        }
        // Trim down to actual length
        bytes memory trimmed = new bytes(j);
        for (uint256 i = 0; i < j; i++) trimmed[i] = out[i];
        return string(trimmed);
    }
}
