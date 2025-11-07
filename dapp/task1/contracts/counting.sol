// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

contract Counting {
    uint256 public count;

    function increment() public {
        count++;
    }
}