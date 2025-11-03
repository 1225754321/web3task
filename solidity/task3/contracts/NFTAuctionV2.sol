// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./NFTAuction.sol";

contract NFTAuctionV2 is NFTAuction {
    function __NFTAuctionV2_init(address _tokenAddress) public initializer {
        __NFTAuction_init(_tokenAddress);
    }

    function Hello() public pure returns (string memory) {
        return "Hello World NFTAuctionV2!";
    }
}
