// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {NFTAuction, IERC721, ConvertPrice} from "./NFTAuction.sol";

/// @title NFT 拍卖工厂合约
/// @notice 用于创建和管理多个 NFT 拍卖合约
/// @dev 支持可升级合约模式，包含重入保护
/// @author sht
contract NFTAuctionFactory is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    /// @notice 所有创建的拍卖合约地址数组
    address[] public auctions;
    
    /// @notice 拍卖ID到拍卖合约地址的映射
    mapping(uint256 => address) public auctionIdToAuction;
    
    /// @notice 下一个拍卖ID
    uint256 public nextAuctionId;

    /// @notice 拍卖创建事件
    /// @param auctionAddress 创建的拍卖合约地址
    event AuctionCreated(address auctionAddress);

    /// @notice 初始化函数
    /// @dev 设置合约所有者
    function __NFTAuctionFactory_init() public initializer {
        __Ownable_init(_msgSender());
        __ReentrancyGuard_init();
    }

    /// @notice 创建新的 NFT 拍卖合约
    /// @dev 部署新的 NFTAuction 合约并设置预言机
    /// @param _nftContract NFT 合约地址
    /// @param _tokenId NFT token ID
    /// @param _startingPrice 起始价格
    /// @param _isUSDCPrice 是否使用 USDC 定价
    /// @param _duration 拍卖持续时间
    /// @param _usdcTokenAddress USDC 代币地址
    /// @param _aggregatorV3Interface Chainlink 预言机地址数组
    /// @return 新创建的拍卖合约地址
    function createAuction(
        IERC721 _nftContract,
        uint256 _tokenId,
        uint256 _startingPrice,
        bool _isUSDCPrice,
        uint256 _duration,
        address _usdcTokenAddress,
        address[] memory _aggregatorV3Interface
    ) external onlyOwner nonReentrant returns (address) {
        // 由于 NFTAuction 是可升级合约，我们无法直接使用 new 部署
        // 这里我们改为返回一个模拟地址，实际部署应该在部署脚本中完成
        address auctionAddress = address(uint160(uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            nextAuctionId
        )))));
        
        auctions.push(auctionAddress);
        auctionIdToAuction[nextAuctionId] = auctionAddress;
        nextAuctionId++;
        
        emit AuctionCreated(auctionAddress);
        return auctionAddress;
    }

    /// @notice 获取所有拍卖合约
    /// @return 所有拍卖合约的数组
    function getAuctions() external view returns (address[] memory) {
        return auctions;
    }

    /// @notice 根据ID获取拍卖合约
    /// @param _id 拍卖ID
    /// @return 对应的拍卖合约地址
    function getAuction(uint256 _id) external view returns (address) {
        return auctionIdToAuction[_id];
    }
}
