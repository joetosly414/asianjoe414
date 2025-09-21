// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../contracts/SimpleApeCoinStaking.sol";
import "../contracts/SimpleERC20.sol";
import "../test/SimpleStakingTest.sol";

/**
 * @title DeploySimpleStaking
 * @dev Simple deployment script without external dependencies
 */
contract DeploySimpleStaking {
    SimpleApeCoinStaking public stakingContract;
    SimpleERC20 public stakingToken;
    SimpleERC20 public rewardToken;
    SimpleStakingTest public testContract;

    event ContractDeployed(string contractName, address contractAddress);
    event DeploymentCompleted(address staking, address stakingToken, address rewardToken);

    function deploy() external {
        // Deploy tokens
        stakingToken = new SimpleERC20(
            "ApeCoin",
            "APE",
            18,
            1_000_000_000e18 // 1 billion tokens
        );
        emit ContractDeployed("StakingToken", address(stakingToken));
        
        rewardToken = new SimpleERC20(
            "RewardToken",
            "RWD",
            18,
            1_000_000_000e18 // 1 billion tokens
        );
        emit ContractDeployed("RewardToken", address(rewardToken));

        // Deploy staking contract
        stakingContract = new SimpleApeCoinStaking(
            address(stakingToken),
            address(rewardToken),
            1e16, // 0.01 tokens per second per token staked
            100_000e18 // 100k token staking cap
        );
        emit ContractDeployed("StakingContract", address(stakingContract));

        // Transfer reward tokens to staking contract
        rewardToken.transfer(address(stakingContract), 10_000_000e18); // 10M rewards

        // Deploy test contract
        testContract = new SimpleStakingTest();
        emit ContractDeployed("TestContract", address(testContract));
        
        emit DeploymentCompleted(
            address(stakingContract),
            address(stakingToken),
            address(rewardToken)
        );
    }

    function getAddresses() external view returns (
        address staking,
        address stakingToken_,
        address rewardToken_,
        address testContract_
    ) {
        return (
            address(stakingContract),
            address(stakingToken),
            address(rewardToken),
            address(testContract)
        );
    }

    function runTests() external {
        require(address(testContract) != address(0), "Test contract not deployed");
        testContract.runTests();
    }
}