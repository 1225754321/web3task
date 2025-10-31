// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract MyNFT is
    UUPSUpgradeable,
    OwnableUpgradeable,
    ERC721Upgradeable,
    IERC721Receiver
{
    mapping(uint256 => string) private tokenUrls;

    function MintNFT(
        address to,
        uint256 tokenId,
        string memory url
    ) external onlyOwner {
        if (bytes(url).length == 0) revert MyERC721Error.InvalidUrl();
        _safeMint(to, tokenId);
        tokenUrls[tokenId] = url;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return tokenUrls[tokenId];
    }

    function initialize(
        string memory name_,
        string memory symbol_
    ) public initializer {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();
        __ERC721_init(name_, symbol_);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

library MyERC721Error {
    // @dev: Error for invalid url
    error InvalidUrl();
}
