// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ReferralRegistry} from "../../contracts/core/ReferralRegistry.sol";

contract DeployReferralRegistry is Script {
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== DEPLOYING REFERRAL REGISTRY ===");
        console.log("Deployer:", deployer);
        console.log("Network:", vm.toString(block.chainid));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy ReferralRegistry
        ReferralRegistry referralRegistry = new ReferralRegistry();
        
        vm.stopBroadcast();
        
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("ReferralRegistry deployed at:", address(referralRegistry));
        console.log("Owner:", deployer);
        console.log("MINTER_ROLE granted to:", deployer);
        console.log("PAUSER_ROLE granted to:", deployer);
        console.log("UPDATER_ROLE granted to:", deployer);
        
        // Verify roles
        require(referralRegistry.hasRole(referralRegistry.DEFAULT_ADMIN_ROLE(), deployer), "Admin role not set");
        require(referralRegistry.hasRole(referralRegistry.MINTER_ROLE(), deployer), "Minter role not set");
        require(referralRegistry.hasRole(referralRegistry.PAUSER_ROLE(), deployer), "Pauser role not set");
        require(referralRegistry.hasRole(referralRegistry.UPDATER_ROLE(), deployer), "Updater role not set");
        
        console.log("=== ROLE VERIFICATION PASSED ===");
        
        // Save deployment info
        // string memory deploymentInfo = string.concat(
        //     "ReferralRegistry deployed at: ",
        //     vm.toString(address(referralRegistry)),
        //     "\\nDeployer: ",
        //     vm.toString(deployer),
        //     "\\nNetwork: ",
        //     vm.toString(block.chainid),
        //     "\\nTimestamp: ",
        //     vm.toString(block.timestamp)
        // );
        
        // vm.writeFile("deployment_referral_registry.txt", deploymentInfo);
        // console.log("Deployment info saved to: deployment_referral_registry.txt");
    }
} 