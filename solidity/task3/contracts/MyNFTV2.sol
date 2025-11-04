// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./MyNFT.sol";

/// @title MyNFT V2 升级版本
/// @notice MyNFT 合约的升级版本，添加了新功能
/// @dev 继承自 MyNFT 合约，支持 UUPS 升级
/// @author sht
contract MyNftV2 is MyNFT {
    /// @notice 测试函数，返回版本信息
    /// @dev 用于验证合约升级是否成功
    /// @return 版本信息字符串
    function Hello() external pure returns (string memory) {
        return "Hello, MyNTF V2!";
    }
}
