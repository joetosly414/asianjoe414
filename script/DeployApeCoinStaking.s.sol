// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/ApeCoinStakingUpgradeable.sol";
import "../contracts/MockERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployApeCoinStaking
 * @dev Deployment script for ApeCoinStaking contracts
 */
contract DeployApeCoinStaking is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with address:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy tokens
        MockERC20 stakingToken = new MockERC20(
            "ApeCoin",
            "APE",
            18,
            1_000_000_000e18 // 1 billion tokens
        );
        
        MockERC20 rewardToken = new MockERC20(
            "RewardToken",
            "RWD",
            18,
            1_000_000_000e18 // 1 billion tokens
        );

        console.log("Staking Token deployed to:", address(stakingToken));
        console.log("Reward Token deployed to:", address(rewardToken));

        // Deploy implementation
        ApeCoinStakingUpgradeable implementation = new ApeCoinStakingUpgradeable();
        console.log("Implementation deployed to:", address(implementation));

        // Prepare initialization data
        bytes memory data = abi.encodeWithSelector(
            ApeCoinStakingUpgradeable.initialize.selector,
            address(stakingToken),
            address(rewardToken),
            1e16, // 0.01 tokens per second per token staked
            100_000e18 // 100k token staking cap
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        console.log("Proxy deployed to:", address(proxy));

        ApeCoinStakingUpgradeable stakingContract = ApeCoinStakingUpgradeable(address(proxy));

        // Transfer some reward tokens to the staking contract
        rewardToken.transfer(address(stakingContract), 10_000_000e18); // 10M rewards
        
        console.log("Deployment completed successfully!");
        console.log("Staking contract (proxy):", address(stakingContract));
        console.log("Staking cap:", stakingContract.stakingCap());
        console.log("Reward rate:", stakingContract.rewardRate());

        vm.stopBroadcast();
    }
}