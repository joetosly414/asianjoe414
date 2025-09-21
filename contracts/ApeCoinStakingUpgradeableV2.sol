// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ApeCoinStakingUpgradeable.sol";

/**
 * @title ApeCoinStakingUpgradeableV2
 * @dev Version 2 of the ApeCoinStaking contract to demonstrate upgradeability
 * Adds version tracking and new functionality
 */
contract ApeCoinStakingUpgradeableV2 is ApeCoinStakingUpgradeable {
    // New state variables for V2
    string public version;
    uint256 public minimumStakeAmount;
    mapping(address => uint256) public userStakeTimestamp;
    
    // New events for V2
    event VersionUpdated(string newVersion);
    event MinimumStakeAmountUpdated(uint256 newMinimumStakeAmount);
    event StakeTimestampRecorded(address indexed user, uint256 timestamp);

    /**
     * @dev Initialize V2 functionality
     * @param _version Version string for this contract
     * @param _minimumStakeAmount Minimum amount required to stake
     */
    function initializeV2(
        string memory _version,
        uint256 _minimumStakeAmount
    ) external reinitializer(2) {
        version = _version;
        minimumStakeAmount = _minimumStakeAmount;
        emit VersionUpdated(_version);
        emit MinimumStakeAmountUpdated(_minimumStakeAmount);
    }

    /**
     * @dev Override stake function to add minimum stake check and timestamp recording
     * @param amount Amount to stake
     */
    function stake(uint256 amount) external override nonReentrant whenNotPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        require(amount >= minimumStakeAmount, "Amount below minimum stake");
        require(stakedBalance[msg.sender] + amount <= stakingCap, "Staking cap exceeded");
        
        totalStaked += amount;
        stakedBalance[msg.sender] += amount;
        userStakeTimestamp[msg.sender] = block.timestamp;
        
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
        emit StakeTimestampRecorded(msg.sender, block.timestamp);
    }

    /**
     * @dev Set the version string (only owner)
     * @param _version New version string
     */
    function setVersion(string memory _version) external onlyOwner {
        version = _version;
        emit VersionUpdated(_version);
    }

    /**
     * @dev Set minimum stake amount (only owner)
     * @param _minimumStakeAmount New minimum stake amount
     */
    function setMinimumStakeAmount(uint256 _minimumStakeAmount) external onlyOwner {
        minimumStakeAmount = _minimumStakeAmount;
        emit MinimumStakeAmountUpdated(_minimumStakeAmount);
    }

    /**
     * @dev Get the time a user has been staking
     * @param user User address
     * @return Time in seconds since last stake
     */
    function getStakingDuration(address user) external view returns (uint256) {
        if (userStakeTimestamp[user] == 0) {
            return 0;
        }
        return block.timestamp - userStakeTimestamp[user];
    }

    /**
     * @dev Get V2 specific information for a user
     * @param user User address
     * @return stakeTimestamp When user last staked
     * @return stakingDuration How long user has been staking
     * @return minimumStake Minimum stake amount required
     */
    function getV2Info(address user) external view returns (
        uint256 stakeTimestamp,
        uint256 stakingDuration,
        uint256 minimumStake
    ) {
        return (
            userStakeTimestamp[user],
            userStakeTimestamp[user] > 0 ? block.timestamp - userStakeTimestamp[user] : 0,
            minimumStakeAmount
        );
    }

    /**
     * @dev Check if user meets minimum stake requirement
     * @param user User address
     * @param amount Amount to stake
     * @return True if amount meets minimum requirement
     */
    function meetsMinimumStake(address user, uint256 amount) external view returns (bool) {
        return amount >= minimumStakeAmount;
    }
}