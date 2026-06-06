// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./OnchainSVG.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title SVGMinter
/// @notice Factory + mint helper. Lets an agent deploy a fresh `OnchainSVG`
///         collection in a single transaction and then mint to it.
contract SVGMinter is Ownable {
    event CollectionCreated(address indexed collection, address indexed owner, string name, string symbol);
    event MintedViaFactory(address indexed collection, address indexed to, uint256 tokenId);

    error CollectionFailed();

    constructor() Ownable(msg.sender) {}

    /// @notice Deploy a new OnchainSVG collection.
    /// @param name The collection name (ERC-721 name)
    /// @param symbol The collection ticker (ERC-721 symbol)
    /// @param collectionOwner The address that will own admin rights on the new collection
    /// @return collection The address of the newly deployed OnchainSVG
    function createCollection(
        string calldata name,
        string calldata symbol,
        address collectionOwner
    ) external returns (address collection) {
        OnchainSVG c = new OnchainSVG(name, symbol, collectionOwner);
        collection = address(c);
        emit CollectionCreated(collection, collectionOwner, name, symbol);
    }

    /// @notice Convenience helper: mint `svg` to `to` on an existing collection.
    ///         The collection must be owned by the caller of this function.
    function mintTo(
        address collection,
        address to,
        string calldata svg
    ) external returns (uint256 tokenId) {
        tokenId = OnchainSVG(collection).mint(to, svg);
        emit MintedViaFactory(collection, to, tokenId);
    }
}
