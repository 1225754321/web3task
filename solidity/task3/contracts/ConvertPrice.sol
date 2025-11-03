// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";

/// @title 价格转换
/// @author sht
contract ConvertPrice is OwnableUpgradeable {
    // 转换内置类型
    mapping(Convert => AggregatorV3Interface) public convertMapping;

    enum Convert {
        ETH_TO_USD,
        USDC_TO_USD
    }

    function aggregatorV3Interface(
        Convert _convert,
        AggregatorV3Interface _dataFeed
    ) external onlyOwner {
        convertMapping[_convert] = _dataFeed;
    }

    function convert(
        Convert _convert,
        uint256 _amount
    ) public view returns (uint256) {
        int256 answer = getChainlinkDataFeedLatestAnswer(_convert);
        return uint256(answer) * _amount;
    }

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

    function __ConvertPrice_init() public initializer {
        __Ownable_init(_msgSender());
    }
}
