// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title 修复版投票合约
 * @dev 完整的投票系统实现，修复了原合约的所有问题
 * @notice 支持候选人管理、投票、查询、重置等完整功能
 * @notice 包含完善的安全控制和事件记录
 */
contract VotingFixed {
    // 合约所有者地址
    address public owner;
    
    // 存储每个候选人的得票数（使用uint256防止溢出）
    mapping(address => uint256) private votings;
    
    // 所有候选人地址数组
    address[] private candidates;
    
    // 投票记录映射：votes[候选人地址][投票人地址] = 投票版本号
    mapping(address => mapping(address => uint8)) private votes;
    
    // 当前投票版本号（uint8类型，最大255，通过require检查防止溢出）
    uint8 private votingVersion = 1;
    
    // 事件定义
    event VoteCast(address indexed voter, address indexed candidate, uint8 version);
    event CandidateAdded(address indexed candidate);
    event VotesReset(uint8 newVersion);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev 仅允许合约所有者调用的修饰器
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     * @dev 验证候选人地址有效性的修饰器
     * @param candidate 要验证的候选人地址
     */
    modifier validCandidate(address candidate) {
        require(candidate != address(0), "Invalid candidate address");
        require(isCandidate(candidate), "Candidate does not exist");
        _;
    }

    /**
     * @dev 构造函数，设置合约部署者为所有者
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev 添加新的候选人
     * @param candidate 候选人地址
     * @notice 仅合约所有者可以调用
     * @notice 验证地址有效性和唯一性
     */
    function addCandidate(address candidate) public onlyOwner {
        require(candidate != address(0), "Invalid candidate address");
        require(!isCandidate(candidate), "Candidate already exists");
        
        candidates.push(candidate);
        emit CandidateAdded(candidate);
    }

    /**
     * @dev 投票函数
     * @param candidate 候选人地址
     * @notice 验证候选人存在性
     * @notice 检查投票人是否在当前轮次已投票
     * @notice 记录投票并触发事件
     */
    function vote(address candidate) public validCandidate(candidate) {
        require(
            votes[candidate][msg.sender] != votingVersion,
            "You have already voted for this candidate in current round"
        );
        
        votings[candidate]++;
        votes[candidate][msg.sender] = votingVersion;
        
        emit VoteCast(msg.sender, candidate, votingVersion);
    }

    /**
     * @dev 获取候选人得票数
     * @param candidate 候选人地址
     * @return 候选人的当前得票数
     * @notice 验证候选人存在性
     */
    function getVotes(address candidate) public view validCandidate(candidate) returns (uint256) {
        return votings[candidate];
    }

    /**
     * @dev 重置所有投票数据
     * @notice 仅合约所有者可以调用
     * @notice 递增版本号并检查溢出
     * @notice 清空所有候选人的得票数
     * @notice 触发重置事件
     */
    function resetVotes() public onlyOwner {
        votingVersion++;
        require(votingVersion > 0, "Version overflow"); // 防止uint8溢出
        
        for (uint256 i = 0; i < candidates.length; i++) {
            votings[candidates[i]] = 0;
        }
        
        emit VotesReset(votingVersion);
    }

    /**
    * @dev 清空所有候选人
    * @notice 仅合约所有者可以调用
    * @notice 该操作不可逆，需谨慎使用
    * @notice 清空候选人后，需重新添加候选人才能继续投票
    */
    function clearCandidates() public onlyOwner {
        candidates = new address[](0);
    }

    /**
     * @dev 获取所有候选人地址数组
     * @return 所有候选人地址数组
     */
    function getCandidates() public view returns (address[] memory) {
        return candidates;
    }

    /**
     * @dev 获取候选人数量
     * @return 当前候选人总数
     */
    function getCandidateCount() public view returns (uint256) {
        return candidates.length;
    }

    /**
     * @dev 检查指定投票人是否已对指定候选人投票
     * @param candidate 候选人地址
     * @param voter 投票人地址
     * @return 如果已投票返回true，否则返回false
     * @notice 验证候选人存在性
     */
    function hasVoted(address candidate, address voter) public view validCandidate(candidate) returns (bool) {
        return votes[candidate][voter] == votingVersion;
    }

    /**
     * @dev 获取当前投票版本号
     * @return 当前投票轮次的版本号
     */
    function getCurrentVersion() public view returns (uint8) {
        return votingVersion;
    }

    /**
     * @dev 检查地址是否为有效候选人
     * @param candidate 要检查的地址
     * @return 如果是候选人返回true，否则返回false
     */
    function isCandidate(address candidate) public view returns (bool) {
        for (uint256 i = 0; i < candidates.length; i++) {
            if (candidates[i] == candidate) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev 转移合约所有权
     * @param newOwner 新的所有者地址
     * @notice 仅当前所有者可以调用
     * @notice 验证新地址有效性
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev 放弃合约所有权
     * @notice 仅当前所有者可以调用
     * @notice 将所有者设置为零地址，合约将无法再被管理
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}