// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title 基础投票合约
 * @dev 这是一个基础的投票合约实现，存在多个安全问题需要修复
 * @notice 此合约仅供学习参考，不建议在生产环境使用
 */
contract Voting {
    // 存储每个候选人的得票数
    mapping(address => uint) private votings;
    
    // 候选人地址数组（注意：此数组从未被填充，需要添加候选人功能）
    address[] private candidates;
    
    // 记录每个地址对每个候选人的投票版本
    // 结构：votes[候选人地址][投票人地址] = 投票版本号
    mapping(address => mapping(address => uint8)) private votes;
    
    // 投票版本号，用于标识不同的投票轮次
    uint8 private VotingVersion = 1;
    
    /**
     * @dev 投票函数
     * @param candidate 候选人地址
     * @notice 存在逻辑错误：条件判断应该是不等于当前版本才允许投票
     * @notice 缺少候选人验证，任何人都可以对任意地址投票
     * @notice 缺少访问控制，任何人都可以调用
     */
    function vote(address candidate) public {
        require(
            votes[candidate][msg.sender] != VotingVersion, // 修复：使用 != 而不是 ==
            "You have already voted for this candidate."
        );
        votings[candidate]++;
        votes[candidate][msg.sender] = VotingVersion;
        for (uint i = 0; i < candidates.length; i++) {
            if (candidates[i] == candidate) {
                return;
            }
        }
        candidates.push(candidate); // 添加新候选人
    }

    /**
     * @dev 获取候选人得票数
     * @param candidate 候选人地址
     * @return 候选人的得票数
     * @notice 缺少候选人存在性验证
     */
    function getVotings(address candidate) public view returns (uint) {
        return votings[candidate];
    }

    /**
     * @dev 重置所有投票
     * @notice 严重安全问题：任何人都可以调用，会导致投票数据被清空
     * @notice 版本号使用uint8，最多只能重置255次
     */
    function resetVotes() public {
        VotingVersion++;
        for (uint i = 0; i < candidates.length; i++) {
            votings[candidates[i]] = 0;
        }
        candidates = new address[](0); 
    }
}
