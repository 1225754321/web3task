// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @title MyNFT 可升级 NFT 合约
/// @notice 支持 UUPS 升级模式的 ERC721 NFT 合约
/// @dev 包含重入保护和所有者权限控制
/// @author sht
contract MyNFT is
    UUPSUpgradeable,
    OwnableUpgradeable,
    ERC721Upgradeable,
    ReentrancyGuardUpgradeable
{
    /// @notice 存储每个 tokenId 对应的元数据 URL
    mapping(uint256 => string) private tokenUrls;

    /// @notice 铸造新的 NFT
    /// @dev 只有合约所有者可以调用此函数
    /// @param to NFT 接收者地址
    /// @param tokenId 要铸造的 token ID
    /// @param url 对应的元数据 URL
    function MintNFT(
        address to,
        uint256 tokenId,
        string memory url
    ) external onlyOwner nonReentrant {
        if (bytes(url).length == 0) revert MyERC721Error.InvalidUrl();
        _safeMint(to, tokenId);
        tokenUrls[tokenId] = url;
    }

    /// @notice 获取指定 tokenId 的元数据 URL
    /// @param tokenId 要查询的 token ID
    /// @return 对应的元数据 URL
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return tokenUrls[tokenId];
    }

    /// @notice 初始化函数
    /// @dev 设置 NFT 名称、符号和所有者
    /// @param name_ NFT 名称
    /// @param symbol_ NFT 符号
    function __MyNFT_init(
        string memory name_,
        string memory symbol_
    ) public initializer {
        __Ownable_init(_msgSender());
        __ERC721_init(name_, symbol_);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /// @notice 授权合约升级
    /// @dev 只有合约所有者可以授权升级
    /// @param newImplementation 新的实现合约地址
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}
}

/// @title MyNFT 错误库
/// @notice 定义 MyNFT 合约使用的自定义错误
library MyERC721Error {
    /// @notice 无效 URL 错误
    /// @dev 当提供的 URL 为空时抛出
    error InvalidUrl();
}
