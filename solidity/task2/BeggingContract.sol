// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BeggingContract {
    mapping(address => uint256) public donationAmount;
    mapping(address => uint256[]) private donorToDonationIndexes;
    address private owner;
    string public seekingHelpInfo;

    struct DonationInfo {
        string description;
        address donor;
        string name;
        uint256 amount;
        uint256 timestamp;
    }

    DonationInfo[] public donations;
    address[3] public mostDonors;
    uint256[3] public mostDonations;

    uint256 public constant MAX_DONATION_RECORDS = 1000;

    // 事件定义
    event DonationReceived(address indexed donor, string name, uint256 amount);
    event Withdrawal(address indexed owner, uint256 amount);
    event HelpInfoUpdated(string newInfo);

    constructor(string memory _seekingHelpInfo) {
        owner = msg.sender;
        seekingHelpInfo = _seekingHelpInfo;
    }

    error NotOwner();
    error InvalidDonation();
    error InvalidInput();
    error MaxDonationsReached();

    modifier onlyOwner() {
        if (owner != msg.sender) revert NotOwner();
        _;
    }

    function updateMost(address donor, uint256 newTotalAmount) internal {
        // 检查捐赠者是否已经在排行榜中
        for (uint i = 0; i < 3; i++) {
            if (mostDonors[i] == donor) {
                mostDonations[i] = newTotalAmount;
                _sortMostDonors();
                return;
            }
        }

        // 新捐赠者：检查是否能进入前三
        for (uint i = 0; i < 3; i++) {
            if (newTotalAmount > mostDonations[i]) {
                for (uint j = 2; j > i; j--) {
                    mostDonors[j] = mostDonors[j - 1];
                    mostDonations[j] = mostDonations[j - 1];
                }
                mostDonors[i] = donor;
                mostDonations[i] = newTotalAmount;
                return;
            }
        }
    }

    function _sortMostDonors() internal {
        for (uint i = 0; i < 2; i++) {
            for (uint j = 0; j < 2 - i; j++) {
                if (mostDonations[j] < mostDonations[j + 1]) {
                    uint256 tempAmount = mostDonations[j];
                    mostDonations[j] = mostDonations[j + 1];
                    mostDonations[j + 1] = tempAmount;

                    address tempDonor = mostDonors[j];
                    mostDonors[j] = mostDonors[j + 1];
                    mostDonors[j + 1] = tempDonor;
                }
            }
        }
    }

    function donate(
        string calldata name,
        string calldata info
    ) public payable virtual returns (string memory) {
        if (msg.value == 0) revert InvalidDonation();
        if (bytes(name).length == 0 || bytes(name).length > 100)
            revert InvalidInput();
        if (bytes(info).length > 500) revert InvalidInput();
        if (donations.length >= MAX_DONATION_RECORDS)
            revert MaxDonationsReached();

        uint256 amount = donationAmount[msg.sender] + msg.value;
        donationAmount[msg.sender] = amount;
        uint256[] storage indexes = donorToDonationIndexes[msg.sender];
        indexes.push(donations.length);

        donations.push(
            DonationInfo(info, msg.sender, name, msg.value, block.timestamp)
        );

        updateMost(msg.sender, amount);

        emit DonationReceived(msg.sender, name, msg.value);
        return "Thank you for your donation";
    }

    function getDonation(
        address donor
    )
        external
        view
        returns (
            uint256 totalAmount,
            uint256 donationCount,
            uint256[] memory indexes
        )
    {
        indexes = donorToDonationIndexes[donor];
        return (donationAmount[donor], indexes.length, indexes);
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        emit Withdrawal(owner, balance);
        payable(owner).transfer(balance);
    }

    function updateHelpInfo(string memory newInfo) external onlyOwner {
        require(bytes(newInfo).length > 0, "Info cannot be empty");
        require(bytes(newInfo).length <= 1000, "Info too long");
        seekingHelpInfo = newInfo;
        emit HelpInfoUpdated(newInfo);
    }

    function getOwner() external view returns (address) {
        return owner;
    }
}

library TimeRestricted {
    uint256 public constant DAY_IN_SECONDS = 24 hours; // 一天的总秒数:cite[9]
    uint256 public constant HOUR_IN_SECONDS = 1 hours;

    error NotInTimeWindow(uint);

    /**
     * @dev 检查当前时间是否在当天的指定小时范围内
     * @param _startHour 开始小时 (0-23)
     * @param _endHour 结束小时 (0-23)
     */
    function executeDuringDailyWindow(
        uint256 _startHour,
        uint256 _endHour,
        uint256 timeZone
    ) public view {
        // 参数验证
        require(_startHour < 24 && _endHour < 24, "Hours must be between 0-23");
        require(_startHour < _endHour, "Start hour must be before end hour");

        // 计算从当天UTC零点开始经过的秒数
        uint256 secondsSinceMidnight = (block.timestamp + timeZone) %
            DAY_IN_SECONDS;

        // 转换为小时（0-23）
        uint256 currentHour = secondsSinceMidnight / HOUR_IN_SECONDS;

        // 检查当前小时是否在指定范围内
        if (currentHour < _startHour || currentHour > _endHour) {
            revert NotInTimeWindow(currentHour);
        }
    }

    /**
     * @dev 更精确的版本 - 检查当前时间是否在当天的指定时间范围内（精确到秒）
     * @param _startTimeOfDay 当天开始时间的秒数 (0-86399)
     * @param _endTimeOfDay 当天结束时间的秒数 (0-86399)
     */
    function executeDuringDailyWindowExact(
        uint256 _startTimeOfDay,
        uint256 _endTimeOfDay,
        uint256 timeZone
    ) public view {
        require(
            _startTimeOfDay < DAY_IN_SECONDS && _endTimeOfDay < DAY_IN_SECONDS,
            "Invalid time range"
        );
        require(
            _startTimeOfDay < _endTimeOfDay,
            "Start time must be before end time"
        );

        uint256 secondsSinceMidnight = (block.timestamp + timeZone) %
            DAY_IN_SECONDS;

        if (
            secondsSinceMidnight < _startTimeOfDay ||
            secondsSinceMidnight > _endTimeOfDay
        ) {
            revert NotInTimeWindow(secondsSinceMidnight);
        }
    }

    // 检查当前时间是否处于指定的开始和结束时间戳范围内
    function executeInSpecificPeriod(
        uint256 _startTime,
        uint256 _endTime,
        uint256 timeZone
    ) public view {
        uint256 nowTime = (block.timestamp + timeZone);
        if (nowTime < _startTime || nowTime > _endTime) {
            revert NotInTimeWindow(nowTime);
        }
    }
}

contract BeggingByTime is BeggingContract {
    uint256 public startTime;
    uint256 public endTime;
    uint256 public timeZone = 8 hours;
    constructor(
        string memory _seekingHelpInfo,
        uint256 _startTime,
        uint256 _endTime
    ) BeggingContract(_seekingHelpInfo) {
        startTime = _startTime;
        endTime = _endTime;
    }
    function donate(
        string calldata name,
        string calldata info
    ) public payable override returns (string memory) {
        TimeRestricted.executeInSpecificPeriod(startTime, endTime, timeZone);
        return super.donate(name, info);
    }
}

contract BeggingByDayHour is BeggingContract {
    uint256 public startTime;
    uint256 public endTime;
    uint256 public timeZone = 8 hours;
    constructor(
        string memory _seekingHelpInfo,
        uint256 _startTime,
        uint256 _endTime
    ) BeggingContract(_seekingHelpInfo) {
        startTime = _startTime;
        endTime = _endTime;
    }
    function donate(
        string calldata name,
        string calldata info
    ) public payable override returns (string memory) {
        TimeRestricted.executeDuringDailyWindow(startTime, endTime, timeZone);
        return super.donate(name, info);
    }
}
