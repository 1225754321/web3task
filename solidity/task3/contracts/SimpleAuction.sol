// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";

/// @title 简单拍卖合约
/// @notice 支持创建、结束和取消拍卖的简单交易合约
/// @author sht
contract SimpleAuction {
    /// @notice 拍卖状态枚举
    enum AuctionStatus {
        Active,
        Ended,
        Cancelled
    }

    /// @notice 拍卖信息结构体
    struct Auction {
        address seller;
        IERC721 nftContract;
        uint256 tokenId;
        uint256 startingPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 startTime;
        uint256 endTime;
        AuctionStatus status;
    }

    /// @notice 拍卖信息
    Auction public auction;

    /// @notice 拍卖创建事件
    event AuctionCreated(
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 startingPrice,
        uint256 startTime,
        uint256 endTime
    );

    /// @notice 出价事件
    event BidPlaced(address indexed bidder, uint256 amount);

    /// @notice 拍卖结束事件
    event AuctionEnded(address indexed winner, uint256 finalPrice);

    /// @notice 拍卖取消事件
    event AuctionCancelled(address indexed seller);

    /// @notice 构造函数
    /// @dev 创建新的拍卖合约，假设NFT已经转移到这个合约
    /// @param _seller 卖家地址
    /// @param _nftContract NFT合约地址
    /// @param _tokenId NFT token ID
    /// @param _startingPrice 起始价格
    /// @param _duration 拍卖持续时间
    constructor(
        address _seller,
        IERC721 _nftContract,
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _duration
    ) {
        require(_startingPrice > 0, "Invalid starting price");
        require(_duration > 0, "Invalid duration");

        // NFT已经工厂合约转移到这个合约地址
        auction = Auction({
            seller: payable(_seller),
            nftContract: _nftContract,
            tokenId: _tokenId,
            startingPrice: _startingPrice,
            highestBid: _startingPrice,
            highestBidder: address(0),
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            status: AuctionStatus.Active
        });

        emit AuctionCreated(
            _seller,
            address(_nftContract),
            _tokenId,
            _startingPrice,
            block.timestamp,
            block.timestamp + _duration
        );
    }

    /// @notice 对拍卖进行出价
    /// @dev 必须发送足够的ETH作为出价
    function placeBid() external payable {
        require(auction.status == AuctionStatus.Active, "Auction not active");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(msg.value > auction.highestBid, "Bid too low");

        // 退还之前的最高出价
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        // 更新最高出价
        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        emit BidPlaced(msg.sender, msg.value);
    }

    /// @notice 结束拍卖
    /// @dev 只有卖家可以结束拍卖
    function endAuction() external {
        require(msg.sender == auction.seller, "Only seller can end auction");
        require(auction.status == AuctionStatus.Active, "Auction not active");
        require(block.timestamp >= auction.endTime, "Auction not ended");

        auction.status = AuctionStatus.Ended;

        if (auction.highestBidder != address(0)) {
            // 转移NFT给最高出价者
            auction.nftContract.transferFrom(
                address(this),
                auction.highestBidder,
                auction.tokenId
            );

            // 转移资金给卖家
            payable(auction.seller).transfer(auction.highestBid);
        } else {
            // 无人出价，退还NFT给卖家
            auction.nftContract.transferFrom(
                address(this),
                auction.seller,
                auction.tokenId
            );
        }

        emit AuctionEnded(auction.highestBidder, auction.highestBid);
    }

    /// @notice 取消拍卖
    /// @dev 只有卖家可以取消拍卖
    function cancelAuction() external {
        require(msg.sender == auction.seller, "Only seller can cancel auction");
        require(auction.status == AuctionStatus.Active, "Auction not active");
        require(block.timestamp < auction.endTime, "Auction already ended");

        auction.status = AuctionStatus.Cancelled;

        // 退还最高出价
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        // 退还NFT给卖家
        auction.nftContract.transferFrom(
            address(this),
            auction.seller,
            auction.tokenId
        );

        emit AuctionCancelled(msg.sender);
    }

    /// @notice 获取拍卖信息
    /// @return 完整的拍卖信息
    function getAuctionInfo() external view returns (Auction memory) {
        return auction;
    }

    /// @notice 检查拍卖是否活跃
    /// @return 如果拍卖活跃返回true，否则返回false
    function isActive() external view returns (bool) {
        return
            auction.status == AuctionStatus.Active &&
            block.timestamp < auction.endTime;
    }

    /// @notice 接收ETH的fallback函数
    receive() external payable {}
}
