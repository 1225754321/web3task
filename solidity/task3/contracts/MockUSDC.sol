// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Mock USDC 代币合约
/// @notice 用于测试的模拟 USDC 代币合约
/// @dev 仅用于开发和测试环境，不应在生产环境中使用
/// @author sht
contract MockUSDC is ERC20 {
    /// @notice 构造函数，初始化代币名称和符号
    /// @dev 向部署者铸造初始供应量
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1000000000000000000000000000);
    }
    
    /// @notice 铸造新的代币
    /// @dev 仅用于测试目的，任何人都可以调用此函数
    /// @param user 接收代币的地址
    /// @param amount 铸造的代币数量
    function mint(address user, uint256 amount) external {
        _mint(user, amount);
    }
}
