// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract MyNFT is
    UUPSUpgradeable,
    OwnableUpgradeable,
    ERC721Upgradeable,
    ReentrancyGuardUpgradeable
{
    mapping(uint256 => string) private tokenUrls;

    function MintNFT(
        address to,
        uint256 tokenId,
        string memory url
    ) external onlyOwner nonReentrant {
        if (bytes(url).length == 0) revert MyERC721Error.InvalidUrl();
        _safeMint(to, tokenId);
        tokenUrls[tokenId] = url;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return tokenUrls[tokenId];
    }

    function __MyNFT_init(
        string memory name_,
        string memory symbol_
    ) public initializer {
        __Ownable_init(_msgSender());
        __ERC721_init(name_, symbol_);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}
}

library MyERC721Error {
    // @dev: Error for invalid url
    error InvalidUrl();
}
