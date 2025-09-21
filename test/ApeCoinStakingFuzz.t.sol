// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/ApeCoinStakingUpgradeable.sol";
import "../contracts/ApeCoinStakingUpgradeableV2.sol";
import "../contracts/MockERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title ApeCoinStakingFuzzTest
 * @dev Advanced fuzz testing suite for ApeCoinStaking contracts
 */
contract ApeCoinStakingFuzzTest is Test {
    ApeCoinStakingUpgradeable public stakingContract;
    ApeCoinStakingUpgradeableV2 public stakingContractV2;
    MockERC20 public stakingToken;
    MockERC20 public rewardToken;
    ERC1967Proxy public proxy;

    address public owner;
    address public user1;
    address public user2;
    address public user3;

    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;
    uint256 public constant INITIAL_REWARD_RATE = 1e18; // 1 token per second per token staked
    uint256 public constant INITIAL_STAKING_CAP = 10_000e18;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    function setUp() public {
        // Setup accounts
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Deploy tokens
        stakingToken = new MockERC20("ApeCoin", "APE", 18, INITIAL_SUPPLY);
        rewardToken = new MockERC20("RewardToken", "RWD", 18, INITIAL_SUPPLY);

        // Deploy implementation
        ApeCoinStakingUpgradeable implementation = new ApeCoinStakingUpgradeable();
        
        // Encode initialization data
        bytes memory data = abi.encodeWithSelector(
            ApeCoinStakingUpgradeable.initialize.selector,
            address(stakingToken),
            address(rewardToken),
            INITIAL_REWARD_RATE,
            INITIAL_STAKING_CAP
        );

        // Deploy proxy
        proxy = new ERC1967Proxy(address(implementation), data);
        stakingContract = ApeCoinStakingUpgradeable(address(proxy));

        // Setup token balances
        stakingToken.mint(user1, 100_000e18);
        stakingToken.mint(user2, 100_000e18);
        stakingToken.mint(user3, 100_000e18);

        // Setup allowances
        vm.prank(user1);
        stakingToken.approve(address(stakingContract), type(uint256).max);
        vm.prank(user2);
        stakingToken.approve(address(stakingContract), type(uint256).max);
        vm.prank(user3);
        stakingToken.approve(address(stakingContract), type(uint256).max);

        // Fund contract with rewards
        rewardToken.transfer(address(stakingContract), 500_000e18);
    }

    /**
     * @dev Fuzz test for single user staking within limits
     */
    function testFuzz_SingleUserStaking(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_STAKING_CAP);
        
        vm.startPrank(user1);
        
        vm.expectEmit(true, false, false, true);
        emit Staked(user1, amount);
        
        stakingContract.stake(amount);
        
        assertEq(stakingContract.stakedBalance(user1), amount);
        assertEq(stakingContract.totalStaked(), amount);
        assertEq(stakingToken.balanceOf(user1), 100_000e18 - amount);
        
        vm.stopPrank();
    }

    /**
     * @dev Fuzz test for staking cap enforcement
     */
    function testFuzz_StakingCapEnforcement(uint256 amount) public {
        amount = bound(amount, INITIAL_STAKING_CAP + 1, type(uint128).max);
        
        vm.startPrank(user1);
        vm.expectRevert("Staking cap exceeded");
        stakingContract.stake(amount);
        vm.stopPrank();
    }

    /**
     * @dev Fuzz test for multi-user staking scenarios
     */
    function testFuzz_MultiUserStaking(
        uint256 amount1,
        uint256 amount2,
        uint256 amount3
    ) public {
        amount1 = bound(amount1, 1, INITIAL_STAKING_CAP);
        amount2 = bound(amount2, 1, INITIAL_STAKING_CAP);
        amount3 = bound(amount3, 1, INITIAL_STAKING_CAP);

        // User 1 stakes
        vm.prank(user1);
        stakingContract.stake(amount1);

        // User 2 stakes
        vm.prank(user2);
        stakingContract.stake(amount2);

        // User 3 stakes
        vm.prank(user3);
        stakingContract.stake(amount3);

        // Verify individual balances
        assertEq(stakingContract.stakedBalance(user1), amount1);
        assertEq(stakingContract.stakedBalance(user2), amount2);
        assertEq(stakingContract.stakedBalance(user3), amount3);

        // Verify total staked
        assertEq(stakingContract.totalStaked(), amount1 + amount2 + amount3);
    }

    /**
     * @dev Fuzz test for withdrawal scenarios
     */
    function testFuzz_Withdrawal(uint256 stakeAmount, uint256 withdrawAmount) public {
        stakeAmount = bound(stakeAmount, 1, INITIAL_STAKING_CAP);
        withdrawAmount = bound(withdrawAmount, 1, stakeAmount);

        vm.startPrank(user1);
        
        // Stake first
        stakingContract.stake(stakeAmount);
        
        // Then withdraw
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(user1, withdrawAmount);
        
        stakingContract.withdraw(withdrawAmount);
        
        assertEq(stakingContract.stakedBalance(user1), stakeAmount - withdrawAmount);
        assertEq(stakingContract.totalStaked(), stakeAmount - withdrawAmount);
        
        vm.stopPrank();
    }

    /**
     * @dev Fuzz test for reward accumulation over time
     */
    function testFuzz_RewardAccumulation(
        uint256 stakeAmount,
        uint256 timeElapsed
    ) public {
        stakeAmount = bound(stakeAmount, 1e18, INITIAL_STAKING_CAP);
        timeElapsed = bound(timeElapsed, 1, 365 days);

        vm.startPrank(user1);
        stakingContract.stake(stakeAmount);
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + timeElapsed);

        uint256 expectedReward = (stakeAmount * INITIAL_REWARD_RATE * timeElapsed) / 1e18;
        uint256 actualReward = stakingContract.earned(user1);

        // Allow for small rounding differences
        assertApproxEqAbs(actualReward, expectedReward, 1e15);
    }

    /**
     * @dev Fuzz test for reward claiming
     */
    function testFuzz_RewardClaiming(uint256 stakeAmount, uint256 timeElapsed) public {
        stakeAmount = bound(stakeAmount, 1e18, INITIAL_STAKING_CAP);
        timeElapsed = bound(timeElapsed, 1, 365 days);

        vm.startPrank(user1);
        stakingContract.stake(stakeAmount);
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + timeElapsed);

        uint256 earnedBefore = stakingContract.earned(user1);
        uint256 balanceBefore = rewardToken.balanceOf(user1);

        vm.prank(user1);
        stakingContract.claimReward();

        uint256 balanceAfter = rewardToken.balanceOf(user1);
        
        assertEq(balanceAfter - balanceBefore, earnedBefore);
        assertEq(stakingContract.earned(user1), 0);
    }

    /**
     * @dev Fuzz test for emergency withdraw functionality
     */
    function testFuzz_EmergencyWithdraw(uint256 stakeAmount) public {
        stakeAmount = bound(stakeAmount, 1, INITIAL_STAKING_CAP);

        vm.prank(user1);
        stakingContract.stake(stakeAmount);

        // Let some time pass to accrue rewards
        vm.warp(block.timestamp + 1000);

        uint256 earnedBefore = stakingContract.earned(user1);
        assertTrue(earnedBefore > 0, "Should have earned some rewards");

        vm.expectEmit(true, false, false, true);
        emit EmergencyWithdraw(user1, stakeAmount);

        stakingContract.emergencyWithdraw(user1);

        // Verify emergency withdrawal
        assertEq(stakingContract.stakedBalance(user1), 0);
        assertEq(stakingContract.rewards(user1), 0); // Rewards forfeited
        assertEq(stakingContract.totalStaked(), 0);
        assertEq(stakingToken.balanceOf(user1), 100_000e18); // Full balance restored
    }

    /**
     * @dev Fuzz test for reward rate updates
     */
    function testFuzz_RewardRateUpdate(uint256 newRewardRate) public {
        newRewardRate = bound(newRewardRate, 0, 10e18);

        stakingContract.setRewardRate(newRewardRate);
        assertEq(stakingContract.rewardRate(), newRewardRate);
    }

    /**
     * @dev Fuzz test for staking cap updates
     */
    function testFuzz_StakingCapUpdate(uint256 newStakingCap) public {
        newStakingCap = bound(newStakingCap, 1, type(uint128).max);

        stakingContract.setStakingCap(newStakingCap);
        assertEq(stakingContract.stakingCap(), newStakingCap);
    }

    /**
     * @dev Fuzz test for multiple stake and withdraw operations
     */
    function testFuzz_MultipleOperations(
        uint256[] memory stakeAmounts,
        uint256[] memory withdrawAmounts
    ) public {
        vm.assume(stakeAmounts.length <= 10);
        vm.assume(withdrawAmounts.length <= stakeAmounts.length);

        uint256 totalStaked = 0;
        uint256 userBalance = 0;

        vm.startPrank(user1);

        for (uint256 i = 0; i < stakeAmounts.length; i++) {
            uint256 amount = bound(stakeAmounts[i], 1, 1000e18);
            
            // Check if staking this amount would exceed cap
            if (totalStaked + amount <= INITIAL_STAKING_CAP) {
                stakingContract.stake(amount);
                totalStaked += amount;
                userBalance += amount;
            }
        }

        for (uint256 i = 0; i < withdrawAmounts.length && userBalance > 0; i++) {
            uint256 amount = bound(withdrawAmounts[i], 1, userBalance);
            stakingContract.withdraw(amount);
            totalStaked -= amount;
            userBalance -= amount;
        }

        assertEq(stakingContract.stakedBalance(user1), userBalance);
        assertEq(stakingContract.totalStaked(), totalStaked);

        vm.stopPrank();
    }

    /**
     * @dev Fuzz test for contract upgrade to V2
     */
    function testFuzz_UpgradeToV2(
        uint256 stakeAmount,
        uint256 minimumStakeAmount
    ) public {
        stakeAmount = bound(stakeAmount, 1, INITIAL_STAKING_CAP);
        minimumStakeAmount = bound(minimumStakeAmount, 1, stakeAmount);

        // Stake in V1
        vm.prank(user1);
        stakingContract.stake(stakeAmount);

        // Upgrade to V2
        ApeCoinStakingUpgradeableV2 implementationV2 = new ApeCoinStakingUpgradeableV2();
        
        vm.startPrank(owner);
        stakingContract.upgradeToAndCall(
            address(implementationV2),
            abi.encodeWithSelector(
                ApeCoinStakingUpgradeableV2.initializeV2.selector,
                "v2.0.0",
                minimumStakeAmount
            )
        );
        vm.stopPrank();

        // Cast to V2
        stakingContractV2 = ApeCoinStakingUpgradeableV2(address(proxy));

        // Verify upgrade preserved state
        assertEq(stakingContractV2.stakedBalance(user1), stakeAmount);
        assertEq(stakingContractV2.version(), "v2.0.0");
        assertEq(stakingContractV2.minimumStakeAmount(), minimumStakeAmount);
    }

    /**
     * @dev Test error cases with invalid inputs
     */
    function testFuzz_ErrorCases(uint256 amount) public {
        // Test staking 0 amount
        vm.prank(user1);
        vm.expectRevert("Cannot stake 0");
        stakingContract.stake(0);

        // Test withdrawing 0 amount
        vm.prank(user1);
        vm.expectRevert("Cannot withdraw 0");
        stakingContract.withdraw(0);

        // Test withdrawing more than staked
        amount = bound(amount, 1, 1000e18);
        vm.prank(user1);
        vm.expectRevert("Insufficient staked balance");
        stakingContract.withdraw(amount);
    }

    /**
     * @dev Test pause functionality
     */
    function testFuzz_PauseFunctionality(uint256 stakeAmount) public {
        stakeAmount = bound(stakeAmount, 1, INITIAL_STAKING_CAP);

        // Pause contract
        stakingContract.pause();

        // Try to stake while paused
        vm.prank(user1);
        vm.expectRevert("Pausable: paused");
        stakingContract.stake(stakeAmount);

        // Unpause and stake should work
        stakingContract.unpause();
        
        vm.prank(user1);
        stakingContract.stake(stakeAmount);
        
        assertEq(stakingContract.stakedBalance(user1), stakeAmount);
    }

    /**
     * @dev Helper function to simulate realistic staking scenario
     */
    function testFuzz_RealisticScenario(
        uint256 user1Amount,
        uint256 user2Amount,
        uint256 timeElapsed1,
        uint256 timeElapsed2
    ) public {
        user1Amount = bound(user1Amount, 1000e18, 5000e18);
        user2Amount = bound(user2Amount, 1000e18, 5000e18);
        timeElapsed1 = bound(timeElapsed1, 1 hours, 30 days);
        timeElapsed2 = bound(timeElapsed2, 1 hours, 30 days);

        // User 1 stakes
        vm.prank(user1);
        stakingContract.stake(user1Amount);

        // Time passes
        vm.warp(block.timestamp + timeElapsed1);

        // User 2 stakes
        vm.prank(user2);
        stakingContract.stake(user2Amount);

        // More time passes
        vm.warp(block.timestamp + timeElapsed2);

        // Both users claim rewards
        uint256 user1RewardsBefore = stakingContract.earned(user1);
        uint256 user2RewardsBefore = stakingContract.earned(user2);

        vm.prank(user1);
        stakingContract.claimReward();

        vm.prank(user2);
        stakingContract.claimReward();

        // Verify rewards were transferred
        assertEq(rewardToken.balanceOf(user1), user1RewardsBefore);
        assertEq(rewardToken.balanceOf(user2), user2RewardsBefore);

        // User 1 should have earned more rewards (staked longer)
        assertTrue(user1RewardsBefore >= user2RewardsBefore);
    }
}