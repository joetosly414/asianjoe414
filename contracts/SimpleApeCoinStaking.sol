// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./SimpleERC20.sol";

/**
 * @title SimpleApeCoinStaking
 * @dev Simple staking contract without upgradeable features for basic testing
 */
contract SimpleApeCoinStaking {
    // State variables
    IERC20 public stakingToken;
    IERC20 public rewardToken;
    address public owner;
    
    uint256 public rewardRate; // rewards per second per token
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public stakingCap; // maximum tokens that can be staked by a single user
    uint256 public totalStaked;
    bool public paused;
    
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public stakedBalance;
    
    // Events
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRewardRate);
    event StakingCapUpdated(uint256 newStakingCap);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardRate,
        uint256 _stakingCap
    ) {
        require(_stakingToken != address(0), "Invalid staking token");
        require(_rewardToken != address(0), "Invalid reward token");
        
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        rewardRate = _rewardRate;
        stakingCap = _stakingCap;
        lastUpdateTime = block.timestamp;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + 
            ((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return (stakedBalance[account] * 
                (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + 
                rewards[account];
    }

    function stake(uint256 amount) external whenNotPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        require(stakedBalance[msg.sender] + amount <= stakingCap, "Staking cap exceeded");
        
        totalStaked += amount;
        stakedBalance[msg.sender] += amount;
        
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");
        
        totalStaked -= amount;
        stakedBalance[msg.sender] -= amount;
        
        require(stakingToken.transfer(msg.sender, amount), "Transfer failed");
        emit Withdrawn(msg.sender, amount);
    }

    function claimReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            require(rewardToken.transfer(msg.sender, reward), "Transfer failed");
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(stakedBalance[msg.sender]);
        claimReward();
    }

    function emergencyWithdraw(address user) external onlyOwner {
        uint256 amount = stakedBalance[user];
        require(amount > 0, "No staked balance");
        
        totalStaked -= amount;
        stakedBalance[user] = 0;
        rewards[user] = 0; // Forfeit rewards in emergency
        
        require(stakingToken.transfer(user, amount), "Transfer failed");
        emit EmergencyWithdraw(user, amount);
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner updateReward(address(0)) {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    function setStakingCap(uint256 _stakingCap) external onlyOwner {
        stakingCap = _stakingCap;
        emit StakingCapUpdated(_stakingCap);
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

    function getStakingInfo(address user) external view returns (
        uint256 staked,
        uint256 earned_,
        uint256 cap
    ) {
        return (stakedBalance[user], earned(user), stakingCap);
    }

    function getGlobalInfo() external view returns (
        uint256 totalStaked_,
        uint256 rewardRate_,
        uint256 rewardPerToken_
    ) {
        return (totalStaked, rewardRate, rewardPerToken());
    }
}