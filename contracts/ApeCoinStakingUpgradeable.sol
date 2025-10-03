// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title ApeCoinStakingUpgradeable
 * @dev Upgradeable staking contract for ApeCoin with caps and rewards
 */
contract ApeCoinStakingUpgradeable is 
    Initializable, 
    OwnableUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // State variables
    IERC20Upgradeable public stakingToken;
    IERC20Upgradeable public rewardToken;
    
    uint256 public rewardRate; // rewards per second per token
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public stakingCap; // maximum tokens that can be staked by a single user
    uint256 public totalStaked;
    
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the contract
     * @param _stakingToken The token to be staked
     * @param _rewardToken The token used for rewards
     * @param _rewardRate Initial reward rate per second per token
     * @param _stakingCap Maximum tokens a user can stake
     */
    function initialize(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardRate,
        uint256 _stakingCap
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        
        require(_stakingToken != address(0), "Invalid staking token");
        require(_rewardToken != address(0), "Invalid reward token");
        
        stakingToken = IERC20Upgradeable(_stakingToken);
        rewardToken = IERC20Upgradeable(_rewardToken);
        rewardRate = _rewardRate;
        stakingCap = _stakingCap;
        lastUpdateTime = block.timestamp;
    }

    /**
     * @dev Modifier to update reward state
     */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /**
     * @dev Calculate reward per token
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + 
            ((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalStaked;
    }

    /**
     * @dev Calculate earned rewards for an account
     */
    function earned(address account) public view returns (uint256) {
        return (stakedBalance[account] * 
                (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + 
                rewards[account];
    }

    /**
     * @dev Stake tokens
     * @param amount Amount to stake
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        require(stakedBalance[msg.sender] + amount <= stakingCap, "Staking cap exceeded");
        
        totalStaked += amount;
        stakedBalance[msg.sender] += amount;
        
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /**
     * @dev Withdraw staked tokens
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");
        
        totalStaked -= amount;
        stakedBalance[msg.sender] -= amount;
        
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @dev Claim accumulated rewards
     */
    function claimReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /**
     * @dev Withdraw all staked tokens and claim rewards
     */
    function exit() external {
        withdraw(stakedBalance[msg.sender]);
        claimReward();
    }

    /**
     * @dev Emergency withdraw without rewards (only owner can call)
     * @param user User to withdraw for
     */
    function emergencyWithdraw(address user) external onlyOwner {
        uint256 amount = stakedBalance[user];
        require(amount > 0, "No staked balance");
        
        totalStaked -= amount;
        stakedBalance[user] = 0;
        rewards[user] = 0; // Forfeit rewards in emergency
        
        stakingToken.safeTransfer(user, amount);
        emit EmergencyWithdraw(user, amount);
    }

    /**
     * @dev Set new reward rate (only owner)
     * @param _rewardRate New reward rate per second per token
     */
    function setRewardRate(uint256 _rewardRate) external onlyOwner updateReward(address(0)) {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    /**
     * @dev Set new staking cap (only owner)
     * @param _stakingCap New staking cap per user
     */
    function setStakingCap(uint256 _stakingCap) external onlyOwner {
        stakingCap = _stakingCap;
        emit StakingCapUpdated(_stakingCap);
    }

    /**
     * @dev Pause the contract (only owner)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract (only owner)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Emergency function to recover tokens (only owner)
     * @param token Token to recover
     * @param amount Amount to recover
     */
    function recoverToken(address token, uint256 amount) external onlyOwner {
        require(token != address(stakingToken), "Cannot recover staking token");
        IERC20Upgradeable(token).safeTransfer(owner(), amount);
    }

    /**
     * @dev Get staking information for a user
     * @param user User address
     * @return staked Amount staked by user
     * @return earned_ Rewards earned by user
     * @return cap Staking cap for user
     */
    function getStakingInfo(address user) external view returns (
        uint256 staked,
        uint256 earned_,
        uint256 cap
    ) {
        return (stakedBalance[user], earned(user), stakingCap);
    }

    /**
     * @dev Get global staking statistics
     * @return totalStaked_ Total amount staked
     * @return rewardRate_ Current reward rate
     * @return rewardPerToken_ Current reward per token
     */
    function getGlobalInfo() external view returns (
        uint256 totalStaked_,
        uint256 rewardRate_,
        uint256 rewardPerToken_
    ) {
        return (totalStaked, rewardRate, rewardPerToken());
    }
}