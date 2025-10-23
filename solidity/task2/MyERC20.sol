// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MyERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18; // 小数位数

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private totalSupplys;
    address private ownerNode;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        ownerNode = msg.sender;
    }

    error AddressZeroErr(address from, address to);
    error ValueIsZero();
    error InsufficientRemainder(uint256 remainder, uint256 value);
    error NotOwner();

    modifier commonCheck(
        address from,
        address to,
        uint256 value
    ) {
        if (from == address(0) || to == address(0))
            revert AddressZeroErr(from, to);
        if (value == 0) revert ValueIsZero();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != ownerNode) revert NotOwner();
        _;
    }

    function changeOwner(address _newOwner) external onlyOwner {
        ownerNode = _newOwner;
    }

    function mint(address to, uint256 value) external onlyOwner {
        totalSupplys += value;
        _balances[to] += value;
        emit Transfer(address(0), to, value);
    }

    function burn(address from, uint256 value) external  onlyOwner {
        if (_balances[from] < value)
            revert InsufficientRemainder(_balances[from], value);
        totalSupplys -= value;
        _balances[from] -= value;
        emit Transfer(from, address(0), value);
    }

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256) {
        return totalSupplys;
    }

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(
        address to,
        uint256 value
    ) external commonCheck(msg.sender, to, value) returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal commonCheck(from, to, value) {
        if (_balances[from] < value)
            revert InsufficientRemainder(_balances[from], value);
        _balances[to] += value;
        _balances[from] -= value;
        emit Transfer(from, to, value);
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function _approve(
        address from,
        address to,
        uint256 value
    ) internal commonCheck(from, to, value) {
        if (_balances[from] < value)
            revert InsufficientRemainder(_balances[from], value);
        _allowances[from][to] += value;
        _balances[from] -= value;
        emit Approval(from, to, value);
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external commonCheck(from, to, value) returns (bool) {
        if (_allowances[from][to] < value)
            revert InsufficientRemainder(_allowances[from][to], value);
        _allowances[from][to] -= value;
        _balances[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
}

