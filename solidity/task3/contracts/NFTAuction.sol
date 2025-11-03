// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ConvertPrice} from "./ConvertPrice.sol";

contract NFTAuction is
    UUPSUpgradeable,
    IERC721Receiver,
    ReentrancyGuardUpgradeable,
    ConvertPrice
{
    // Custom Errors
    error InvalidStartingPrice(uint256 startingPrice);
    error InvalidDuration(
        uint256 duration,
        uint256 minDuration,
        uint256 maxDuration
    );
    error InvalidBidAmountCombination();
    error ZeroBidAmount();
    error AuctionNotStarted(uint64 startTime);
    error AuctionAlreadyEnded();
    error AuctionNotEnded(uint64 endTime);
    error BidTooLow(uint256 convertedBidAmount, uint256 convertedHighestBid);
    error UnauthorizedSeller();
    error TransferFailed();
    error UnsupportedBidToken(address token);

    using SafeERC20 for IERC20;

    uint256 public constant MIN_AUCTION_DURATION = 1 hours;
    uint256 public constant MAX_AUCTION_DURATION = 7 days;

    event AuctionCreated(uint256 auctionId);

    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        address bidToken
    );
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 finalPrice,
        address bidToken,
        address indexed seller
    );
    event AuctionCancelled(uint256 indexed auctionId, address indexed seller);

    struct Auction {
        // NFT ID (Slot 0)
        uint256 tokenId;
        // 卖家 (Slot 1)
        address payable seller;
        // 最高出价者 (Slot 2)
        address payable highestBidder;
        // NFT合约地址 (Slot 3)
        IERC721 nftContract;
        // 代币合约 x0代表ETH 其他代表ERC20 (Slot 4)
        IERC20 bidToken;
        // 起始价格 (Slot 5, 16 bytes)
        uint128 startingPrice;
        // 最高出价 (Slot 5, 16 bytes)
        uint128 highestBid;
        // 开始时间 (Slot 6, 8 bytes)
        uint64 startTime;
        // 计算结束时间 (Slot 6, 8 bytes)
        uint64 endTime;
        // 是否结束 (Slot 6, 1 byte)
        bool ended;
    }

    // 状态变量
    mapping(uint256 => Auction) public auctions;
    // 下一个拍卖ID
    uint256 public nextAuctionId;

    // USDC 代币地址
    address public usdcTokenAddress;

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

    fallback() external payable {}

    receive() external payable {}

    function __NFTAuction_init(address _usdcTokenAddress) public initializer {
        __ReentrancyGuard_init();
        __ConvertPrice_init();
        __UUPSUpgradeable_init();
        setUsdcTokenAddress(_usdcTokenAddress);
    }

    function setUsdcTokenAddress(address _usdcTokenAddress) public onlyOwner {
        usdcTokenAddress = _usdcTokenAddress;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}

    function onERC721Received(
        address /* _operator */,
        address /* _from */,
        uint256 /*_tokenId */,
        bytes calldata /* _data */
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
