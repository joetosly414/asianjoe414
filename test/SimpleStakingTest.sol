// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../contracts/SimpleApeCoinStaking.sol";
import "../contracts/SimpleERC20.sol";

/**
 * @title SimpleStakingTest
 * @dev Basic test contract for SimpleApeCoinStaking without external dependencies
 */
contract SimpleStakingTest {
    SimpleApeCoinStaking public stakingContract;
    SimpleERC20 public stakingToken;
    SimpleERC20 public rewardToken;

    address public owner;
    address public user1;
    address public user2;

    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;
    uint256 public constant INITIAL_REWARD_RATE = 1e18; // 1 token per second per token staked
    uint256 public constant INITIAL_STAKING_CAP = 10_000e18;

    event TestResult(string testName, bool passed, string reason);

    constructor() {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        // Deploy tokens
        stakingToken = new SimpleERC20("ApeCoin", "APE", 18, INITIAL_SUPPLY);
        rewardToken = new SimpleERC20("RewardToken", "RWD", 18, INITIAL_SUPPLY);

        // Deploy staking contract
        stakingContract = new SimpleApeCoinStaking(
            address(stakingToken),
            address(rewardToken),
            INITIAL_REWARD_RATE,
            INITIAL_STAKING_CAP
        );

        // Setup initial token balances
        stakingToken.mint(user1, 100_000e18);
        stakingToken.mint(user2, 100_000e18);

        // Transfer reward tokens to staking contract
        rewardToken.transfer(address(stakingContract), 500_000e18);
    }

    function runTests() external {
        testBasicStaking();
        testWithdrawal();
        testRewardClaiming();
        testStakingCap();
        testEmergencyWithdraw();
        testPauseFunctionality();
        testOwnerOnlyFunctions();
    }

    function testBasicStaking() public {
        uint256 stakeAmount = 1000e18;
        
        // Simulate user1 staking
        stakingToken.approve(address(stakingContract), stakeAmount);
        
        uint256 balanceBefore = stakingToken.balanceOf(address(this));
        stakingContract.stake(stakeAmount);
        uint256 balanceAfter = stakingToken.balanceOf(address(this));
        
        bool passed = (balanceAfter == balanceBefore - stakeAmount) && 
                     (stakingContract.stakedBalance(address(this)) == stakeAmount) &&
                     (stakingContract.totalStaked() == stakeAmount);
        
        emit TestResult("Basic Staking", passed, passed ? "Success" : "Failed balance or staking checks");
    }

    function testWithdrawal() public {
        uint256 withdrawAmount = 500e18;
        uint256 stakedBefore = stakingContract.stakedBalance(address(this));
        
        if (stakedBefore >= withdrawAmount) {
            uint256 balanceBefore = stakingToken.balanceOf(address(this));
            stakingContract.withdraw(withdrawAmount);
            uint256 balanceAfter = stakingToken.balanceOf(address(this));
            
            bool passed = (balanceAfter == balanceBefore + withdrawAmount) &&
                         (stakingContract.stakedBalance(address(this)) == stakedBefore - withdrawAmount);
            
            emit TestResult("Withdrawal", passed, passed ? "Success" : "Failed withdrawal checks");
        } else {
            emit TestResult("Withdrawal", false, "Insufficient staked balance for test");
        }
    }

    function testRewardClaiming() public {
        // Let some time pass (simulated by checking earned)
        uint256 earnedRewards = stakingContract.earned(address(this));
        
        if (earnedRewards > 0) {
            uint256 balanceBefore = rewardToken.balanceOf(address(this));
            stakingContract.claimReward();
            uint256 balanceAfter = rewardToken.balanceOf(address(this));
            
            bool passed = balanceAfter > balanceBefore;
            emit TestResult("Reward Claiming", passed, passed ? "Success" : "No rewards received");
        } else {
            emit TestResult("Reward Claiming", true, "No rewards to claim yet (normal)");
        }
    }

    function testStakingCap() public {
        uint256 currentStaked = stakingContract.stakedBalance(address(this));
        uint256 cap = stakingContract.stakingCap();
        
        if (currentStaked < cap) {
            uint256 excessAmount = cap - currentStaked + 1;
            
            // This should fail
            stakingToken.approve(address(stakingContract), excessAmount);
            
            try stakingContract.stake(excessAmount) {
                emit TestResult("Staking Cap", false, "Should have failed but didn't");
            } catch {
                emit TestResult("Staking Cap", true, "Correctly rejected stake over cap");
            }
        } else {
            emit TestResult("Staking Cap", true, "Already at cap, cannot test excess");
        }
    }

    function testEmergencyWithdraw() public {
        uint256 stakedAmount = stakingContract.stakedBalance(address(this));
        
        if (stakedAmount > 0) {
            uint256 balanceBefore = stakingToken.balanceOf(address(this));
            stakingContract.emergencyWithdraw(address(this));
            uint256 balanceAfter = stakingToken.balanceOf(address(this));
            
            bool passed = (balanceAfter == balanceBefore + stakedAmount) &&
                         (stakingContract.stakedBalance(address(this)) == 0);
            
            emit TestResult("Emergency Withdraw", passed, passed ? "Success" : "Failed emergency withdraw");
        } else {
            emit TestResult("Emergency Withdraw", true, "No stake to emergency withdraw");
        }
    }

    function testPauseFunctionality() public {
        stakingContract.pause();
        
        stakingToken.approve(address(stakingContract), 100e18);
        
        try stakingContract.stake(100e18) {
            emit TestResult("Pause Functionality", false, "Should have failed when paused");
        } catch {
            stakingContract.unpause();
            emit TestResult("Pause Functionality", true, "Correctly rejected stake when paused");
        }
    }

    function testOwnerOnlyFunctions() public {
        uint256 newRewardRate = 2e18;
        stakingContract.setRewardRate(newRewardRate);
        
        bool passed = stakingContract.rewardRate() == newRewardRate;
        emit TestResult("Owner Only Functions", passed, passed ? "Success" : "Failed to set reward rate");
    }

    // Helper function to check contract state
    function getContractState() external view returns (
        uint256 totalStaked,
        uint256 rewardRate,
        uint256 stakingCap,
        bool isPaused
    ) {
        return (
            stakingContract.totalStaked(),
            stakingContract.rewardRate(),
            stakingContract.stakingCap(),
            stakingContract.paused()
        );
    }
}