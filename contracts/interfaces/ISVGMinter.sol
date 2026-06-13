// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISVGMinter
/// @notice External interface for the SVGM factory contract.
interface ISVGMinter {
    function createCollection(
        string calldata name,
        string calldata symbol,
        address collectionOwner
    ) external returns (address collection);

    function mintTo(
        address collection,
        address to,
        string calldata svg
    ) external returns (uint256 tokenId);

    event CollectionCreated(address indexed collection, address indexed owner, string name, string symbol);
    event MintedViaFactory(address indexed collection, address indexed to, uint256 tokenId);
}
