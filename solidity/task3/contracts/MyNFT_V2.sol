// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./MyNFT.sol";

contract MyNFT_V2 is MyNFT {
    function Hello() external pure returns (string memory) {
        return "Hello, MyNTF V2!";
    }
}
