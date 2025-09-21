// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/ApeCoinStakingUpgradeableV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title UpgradeApeCoinStaking
 * @dev Script to upgrade ApeCoinStaking to V2
 */
contract UpgradeApeCoinStaking is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deploxyAddress = vm.envAddress("PROXY_ADDRESS");
        
        console.log("Upgrading ApeCoinStaking contract at:", deploxyAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementation
        ApeCoinStakingUpgradeableV2 newImplementation = new ApeCoinStakingUpgradeableV2();
        console.log("New implementation deployed to:", address(newImplementation));

        // Get proxy contract
        ERC1967Proxy proxy = ERC1967Proxy(payable(deploxyAddress));
        
        // Prepare V2 initialization data
        bytes memory initData = abi.encodeWithSelector(
            ApeCoinStakingUpgradeableV2.initializeV2.selector,
            "v2.0.0",
            1000e18 // 1000 token minimum stake
        );

        // Upgrade proxy
        ApeCoinStakingUpgradeableV2(address(proxy)).upgradeToAndCall(
            address(newImplementation),
            initData
        );

        console.log("Upgrade completed successfully!");
        
        ApeCoinStakingUpgradeableV2 upgradedContract = ApeCoinStakingUpgradeableV2(address(proxy));
        console.log("New version:", upgradedContract.version());
        console.log("Minimum stake amount:", upgradedContract.minimumStakeAmount());

        vm.stopBroadcast();
    }
}