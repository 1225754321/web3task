// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./NFTAuction.sol";

/// @title NFT 拍卖合约 V2 升级版本
/// @notice NFTAuction 合约的升级版本，添加了新功能
/// @dev 继承自 NFTAuction 合约，支持 UUPS 升级
/// @author sht
contract NFTAuctionV2 is NFTAuction {
    /// @notice 初始化函数
    /// @dev 设置合约初始状态和 USDC 代币地址
    /// @param _tokenAddress USDC 代币地址
    function __NFTAuctionV2_init(address _tokenAddress) public initializer {
        __NFTAuction_init(_tokenAddress);
    }

    /// @notice 测试函数，返回版本信息
    /// @dev 用于验证合约升级是否成功
    /// @return 版本信息字符串
    function Hello() public pure returns (string memory) {
        return "Hello World NFTAuctionV2!";
    }
}
