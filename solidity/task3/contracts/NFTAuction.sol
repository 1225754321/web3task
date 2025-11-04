// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ConvertPrice} from "./ConvertPrice.sol";

/// @title NFT 拍卖合约
/// @notice 支持 ETH 和 USDC 出价的 NFT 拍卖系统
/// @dev 使用 Chainlink 预言机进行价格转换，支持 UUPS 升级
/// @author sht
contract NFTAuction is
    UUPSUpgradeable,
    IERC721Receiver,
    ReentrancyGuardUpgradeable,
    ConvertPrice
{
    // Custom Errors
    /// @notice 起始价格无效错误
    /// @param startingPrice 无效的起始价格
    error InvalidStartingPrice(uint256 startingPrice);
    
    /// @notice 拍卖时长无效错误
    /// @param duration 提供的时长
    /// @param minDuration 最小允许时长
    /// @param maxDuration 最大允许时长
    error InvalidDuration(
        uint256 duration,
        uint256 minDuration,
        uint256 maxDuration
    );
    
    /// @notice 出价金额组合无效错误
    error InvalidBidAmountCombination();
    
    /// @notice 零出价金额错误
    error ZeroBidAmount();
    
    /// @notice 拍卖未开始错误
    /// @param startTime 拍卖开始时间
    error AuctionNotStarted(uint64 startTime);
    
    /// @notice 拍卖已结束错误
    error AuctionAlreadyEnded();
    
    /// @notice 拍卖未结束错误
    /// @param endTime 拍卖结束时间
    error AuctionNotEnded(uint64 endTime);
    
    /// @notice 出价过低错误
    /// @param convertedBidAmount 转换后的出价金额
    /// @param convertedHighestBid 转换后的最高出价
    error BidTooLow(uint256 convertedBidAmount, uint256 convertedHighestBid);
    
    /// @notice 未授权卖家错误
    error UnauthorizedSeller();
    
    /// @notice 转账失败错误
    error TransferFailed();
    
    /// @notice 不支持的出价代币错误
    /// @param token 不支持的代币地址
    error UnsupportedBidToken(address token);

    using SafeERC20 for IERC20;

    /// @notice 最小拍卖时长（1小时）
    uint256 public constant MIN_AUCTION_DURATION = 1 hours;
    
    /// @notice 最大拍卖时长（7天）
    uint256 public constant MAX_AUCTION_DURATION = 7 days;

    /// @notice 拍卖创建事件
    /// @param auctionId 创建的拍卖ID
    event AuctionCreated(uint256 auctionId);

    /// @notice 出价事件
    /// @param auctionId 拍卖ID
    /// @param bidder 出价者地址
    /// @param amount 出价金额
    /// @param bidToken 出价代币地址
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        address bidToken
    );
    
    /// @notice 拍卖结束事件
    /// @param auctionId 拍卖ID
    /// @param winner 获胜者地址
    /// @param finalPrice 最终价格
    /// @param bidToken 出价代币地址
    /// @param seller 卖家地址
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 finalPrice,
        address bidToken,
        address indexed seller
    );
    
    /// @notice 拍卖取消事件
    /// @param auctionId 拍卖ID
    /// @param seller 卖家地址
    event AuctionCancelled(uint256 indexed auctionId, address indexed seller);

    /// @notice 拍卖结构体
    /// @dev 存储拍卖相关信息，优化存储布局
    struct Auction {
        /// @notice NFT ID (Slot 0)
        uint256 tokenId;
        /// @notice 卖家地址 (Slot 1)
        address payable seller;
        /// @notice 最高出价者地址 (Slot 2)
        address payable highestBidder;
        /// @notice NFT合约地址 (Slot 3)
        IERC721 nftContract;
        /// @notice 出价代币合约地址，address(0)代表ETH，其他代表ERC20 (Slot 4)
        IERC20 bidToken;
        /// @notice 起始价格 (Slot 5, 16 bytes)
        uint128 startingPrice;
        /// @notice 最高出价 (Slot 5, 16 bytes)
        uint128 highestBid;
        /// @notice 开始时间 (Slot 6, 8 bytes)
        uint64 startTime;
        /// @notice 结束时间 (Slot 6, 8 bytes)
        uint64 endTime;
        /// @notice 是否结束 (Slot 6, 1 byte)
        bool ended;
    }

    /// @notice 拍卖ID到拍卖信息的映射
    mapping(uint256 => Auction) public auctions;
    
    /// @notice 下一个拍卖ID
    uint256 public nextAuctionId;

    /// @notice USDC 代币地址
    address public usdcTokenAddress;

    /// @notice 创建新的 NFT 拍卖
    /// @dev 将 NFT 转移到合约并设置拍卖参数
    /// @param nftContract NFT 合约地址
    /// @param tokenId NFT token ID
    /// @param startingPrice 起始价格
    /// @param isUSDCPrice 是否使用 USDC 定价（true 为 USDC，false 为 ETH）
    /// @param duration 拍卖持续时间
    function createAuction(
        IERC721 nftContract,
        uint256 tokenId,
        uint256 startingPrice,
        bool isUSDCPrice,
        uint256 duration
    ) external nonReentrant {
        if (startingPrice == 0) {
            revert InvalidStartingPrice(startingPrice);
        }
        if (
            duration <= MIN_AUCTION_DURATION || duration > MAX_AUCTION_DURATION
        ) {
            revert InvalidDuration(
                duration,
                MIN_AUCTION_DURATION,
                MAX_AUCTION_DURATION
            );
        }

        uint256 auctionId = nextAuctionId;

        nftContract.safeTransferFrom(msg.sender, address(this), tokenId);

        IERC20 bidToken = IERC20(address(0));
        if (isUSDCPrice) {
            bidToken = IERC20(usdcTokenAddress);
        }

        auctions[auctionId] = Auction({
            seller: payable(msg.sender),
            bidToken: bidToken,
            startingPrice: uint128(startingPrice),
            startTime: uint64(block.timestamp),
            endTime: uint64(block.timestamp + duration),
            highestBid: uint128(startingPrice),
            highestBidder: payable(address(0)),
            nftContract: nftContract,
            tokenId: tokenId,
            ended: false
        });

        nextAuctionId++;

        emit AuctionCreated(auctionId);
    }

    /// @notice 对拍卖进行出价
    /// @dev 支持 ETH 和 USDC 出价，使用 Chainlink 预言机进行价格比较
    /// @param _auctionID 拍卖 ID
    /// @param _amount 出价金额（对于 ERC20 代币）
    /// @param _tokenAddress 出价代币地址（address(0) 表示 ETH）
    function placeBid(
        uint256 _auctionID,
        uint256 _amount,
        IERC20 _tokenAddress
    ) external payable nonReentrant {
        if (_amount > 0 && msg.value > 0) {
            revert InvalidBidAmountCombination();
        }
        if (_amount <= 0 && msg.value > 0) {
            _amount = msg.value;
        }
        if (_amount == 0) {
            revert ZeroBidAmount();
        }
        Auction storage auction = auctions[_auctionID];
        if (auction.startTime > block.timestamp) {
            revert AuctionNotStarted(auction.startTime);
        }
        if (auction.endTime < block.timestamp || auction.ended) {
            revert AuctionAlreadyEnded();
        }
        uint256 convertedBidAmount;
        uint256 convertedHighestBid;
        // 转换出价至等价USD
        if (address(_tokenAddress) == address(0)) {
            // ETH
            convertedBidAmount = convert(
                ConvertPrice.Convert.ETH_TO_USD,
                _amount
            );
        } else if (address(_tokenAddress) == usdcTokenAddress) {
            // USDC
            convertedBidAmount = convert(
                ConvertPrice.Convert.USDC_TO_USD,
                _amount
            );
        } else {
            revert UnsupportedBidToken(address(_tokenAddress));
        }

        // 转换历史最高价至等价USD
        if (address(auction.bidToken) == address(0)) {
            // ETH
            convertedHighestBid = convert(
                ConvertPrice.Convert.ETH_TO_USD,
                auction.highestBid
            );
        } else if (address(auction.bidToken) == usdcTokenAddress) {
            // USDC
            convertedHighestBid = convert(
                ConvertPrice.Convert.USDC_TO_USD,
                auction.highestBid
            );
        } else {
            // 理论上不应该发生，因为只有 ETH 或 USDC 才能开始拍卖
            // 但为了安全起见，如果历史出价代币不是 ETH 或 USDC，则抛出错误
            revert UnsupportedBidToken(address(auction.bidToken));
        }
        if (convertedBidAmount <= convertedHighestBid) {
            revert BidTooLow(convertedBidAmount, convertedHighestBid);
        }
        // 获取当前最高价
        if (address(_tokenAddress) != address(0)) {
            _tokenAddress.safeTransferFrom(msg.sender, address(this), _amount);
        }
        // 退还之前最高出价
        if (address(auction.highestBidder) != address(0)) {
            bool success;
            if (address(auction.bidToken) == address(0)) {
                (success, ) = auction.highestBidder.call{
                    value: auction.highestBid
                }("");
            } else {
                success = auction.bidToken.trySafeTransfer(
                    auction.highestBidder,
                    auction.highestBid
                );
            }
            if (!success) {
                revert TransferFailed();
            }
        }
        // 更新
        auction.highestBidder = payable(_msgSender());
        auction.bidToken = _tokenAddress;
        auction.highestBid = uint128(_amount);

        emit BidPlaced(
            _auctionID,
            _msgSender(),
            _amount,
            address(_tokenAddress)
        );
    }

    /// @notice 结束拍卖
    /// @dev 将 NFT 转移给最高出价者，将资金转移给卖家
    /// @param _auctionID 拍卖 ID
    function endAuction(uint256 _auctionID) external nonReentrant {
        Auction storage auction = auctions[_auctionID];
        if (auction.endTime >= block.timestamp) {
            revert AuctionNotEnded(auction.endTime);
        }
        if (auction.ended) {
            revert AuctionAlreadyEnded();
        }

        auction.ended = true;

        // 转给最高出价
        if (address(auction.highestBidder) != address(0)) {
            auction.nftContract.safeTransferFrom(
                address(this),
                auction.highestBidder,
                auction.tokenId
            );
            // 转给卖家
            bool success;
            if (address(auction.bidToken) == address(0)) {
                (success, ) = auction.seller.call{value: auction.highestBid}(
                    ""
                );
            } else {
                success = auction.bidToken.trySafeTransfer(
                    auction.seller,
                    auction.highestBid
                );
            }
            if (!success) {
                revert TransferFailed();
            }
        } else {
            auction.nftContract.safeTransferFrom(
                address(this),
                auction.seller,
                auction.tokenId
            );
        }

        address winner = auction.highestBidder;
        uint256 finalPrice = (winner != address(0)) ? auction.highestBid : 0;
        address bidToken = (winner != address(0))
            ? address(auction.bidToken)
            : address(0);

        emit AuctionEnded(
            _auctionID,
            winner,
            finalPrice,
            bidToken,
            auction.seller
        );
    }

    /// @notice 取消拍卖
    /// @dev 只有卖家可以取消拍卖，退还所有出价
    /// @param _auctionID 拍卖 ID
    function cancelAuction(uint256 _auctionID) external nonReentrant {
        Auction storage auction = auctions[_auctionID];
        if (_msgSender() != auction.seller) {
            revert UnauthorizedSeller();
        }
        // 无法取消已经结束的拍卖
        if (auction.ended) {
            revert AuctionAlreadyEnded();
        }
        if (block.timestamp >= auction.endTime) {
            revert AuctionAlreadyEnded();
        }

        auction.ended = true;
        if (address(auction.highestBidder) != address(0)) {
            bool success;
            if (address(auction.bidToken) == address(0)) {
                (success, ) = auction.highestBidder.call{
                    value: auction.highestBid
                }("");
            } else {
                success = auction.bidToken.trySafeTransfer(
                    auction.highestBidder,
                    auction.highestBid
                );
            }
            if (!success) {
                revert TransferFailed();
            }
        }
        auction.nftContract.safeTransferFrom(
            address(this),
            auction.seller,
            auction.tokenId
        );

        emit AuctionCancelled(_auctionID, _msgSender());
    }

    /// @notice Fallback 函数
    /// @dev 接收 ETH 转账
    fallback() external payable {}

    /// @notice Receive 函数
    /// @dev 接收 ETH 转账
    receive() external payable {}

    /// @notice 初始化函数
    /// @dev 设置合约初始状态和 USDC 代币地址
    /// @param _usdcTokenAddress USDC 代币地址
    function __NFTAuction_init(address _usdcTokenAddress) public initializer {
        __ReentrancyGuard_init();
        __ConvertPrice_init();
        __UUPSUpgradeable_init();
        setUsdcTokenAddress(_usdcTokenAddress);
    }

    /// @notice 设置 USDC 代币地址
    /// @dev 只有合约所有者可以调用此函数
    /// @param _usdcTokenAddress USDC 代币地址
    function setUsdcTokenAddress(address _usdcTokenAddress) public onlyOwner {
        usdcTokenAddress = _usdcTokenAddress;
    }

    /// @notice 授权合约升级
    /// @dev 只有合约所有者可以授权升级
    /// @param newImplementation 新的实现合约地址
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}

    /// @notice ERC721 接收函数
    /// @dev 实现 IERC721Receiver 接口，用于接收 NFT
    /// @return 函数选择器
    function onERC721Received(
        address /* _operator */,
        address /* _from */,
        uint256 /*_tokenId */,
        bytes calldata /* _data */
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
