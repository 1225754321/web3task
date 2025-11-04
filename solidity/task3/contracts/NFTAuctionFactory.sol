// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {SimpleAuction} from "./SimpleAuction.sol";

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
    /// @dev 部署新的 SimpleAuction 合约，并转移NFT到拍卖合约
    /// @param _nftContract NFT 合约地址
    /// @param _tokenId NFT token ID
    /// @param _startingPrice 起始价格
    /// @param _duration 拍卖持续时间
    /// @return 新创建的拍卖合约地址
    function createAuction(
        IERC721 _nftContract,
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _duration
    ) external onlyOwner nonReentrant returns (address) {
        // 先部署拍卖合约
        SimpleAuction auction = new SimpleAuction(
            _msgSender(),
            _nftContract,
            _tokenId,
            _startingPrice,
            _duration
        );

        address auctionAddress = address(auction);

        // 转移NFT到拍卖合约
        _nftContract.transferFrom(msg.sender, auctionAddress, _tokenId);

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
