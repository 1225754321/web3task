// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {NFTAuctionFactory} from "./NFTAuctionFactory.sol";

/// @title NFT 拍卖工厂 V2 升级版本
/// @notice NFTAuctionFactory 合约的升级版本，添加了新功能
/// @dev 继承自 NFTAuctionFactory 合约
/// @author sht
contract NFTAuctionFactoryV2 is NFTAuctionFactory {
    /// @notice 测试函数，返回版本信息
    /// @dev 用于验证合约升级是否成功
    /// @return 版本信息字符串
    function Hello() public pure returns (string memory) {
        return "Hello World NFTAuctionFactoryV2!";
    }
}
