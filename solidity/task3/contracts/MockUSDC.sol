// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1000000000000000000000000000);
    }
    // 纯测试用!!!
    function mint(address user,uint256 amount)  external {
        _mint(user, amount);
    }
}
