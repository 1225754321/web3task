// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";

/// @title 价格转换合约
/// @notice 使用 Chainlink 预言机进行价格转换，支持 ETH/USD 和 USDC/USD 转换
/// @author sht
contract ConvertPrice is OwnableUpgradeable {
    /// @notice 转换类型到 Chainlink 数据源的映射
    /// @dev 存储不同转换类型对应的 Chainlink 预言机地址
    mapping(Convert => AggregatorV3Interface) public convertMapping;

    /// @notice 支持的转换类型枚举
    enum Convert {
        ETH_TO_USD,  // ETH 到 USD 的转换
        USDC_TO_USD  // USDC 到 USD 的转换
    }

    /// @notice 设置指定转换类型的 Chainlink 数据源
    /// @dev 只有合约所有者可以调用此函数
    /// @param _convert 转换类型
    /// @param _dataFeed Chainlink 预言机合约地址
    function aggregatorV3Interface(
        Convert _convert,
        AggregatorV3Interface _dataFeed
    ) external onlyOwner {
        convertMapping[_convert] = _dataFeed;
    }

    /// @notice 将指定数量的代币转换为 USD 价值
    /// @param _convert 转换类型
    /// @param _amount 要转换的代币数量
    /// @return 转换后的 USD 价值
    function convert(
        Convert _convert,
        uint256 _amount
    ) public view returns (uint256) {
        int256 answer = getChainlinkDataFeedLatestAnswer(_convert);
        return uint256(answer) * _amount;
    }

    /// @notice 获取指定转换类型的最新价格数据
    /// @param _convert 转换类型
    /// @return 最新的价格数据（通常为 8 位小数）
    function getChainlinkDataFeedLatestAnswer(
        Convert _convert
    ) public view returns (int256) {
        // prettier-ignore
        (
      /* uint80 roundId */
      ,
      int256 answer,
      /*uint256 startedAt*/
      ,
      /*uint256 updatedAt*/
      ,
      /*uint80 answeredInRound*/
    ) = convertMapping[_convert].latestRoundData();
        return answer;
    }

    /// @notice 初始化函数
    /// @dev 可升级合约的初始化函数，设置合约所有者
    function __ConvertPrice_init() public initializer {
        __Ownable_init(_msgSender());
    }
}
