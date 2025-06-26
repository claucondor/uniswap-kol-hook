// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TVLLeaderboard} from "../../contracts/periphery/TVLLeaderboard.sol";

contract DeployTVLLeaderboard is Script {
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== DEPLOYING TVL LEADERBOARD ===");
        console.log("Deployer:", deployer);
        console.log("Network:", vm.toString(block.chainid));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy TVLLeaderboard
        TVLLeaderboard tvlLeaderboard = new TVLLeaderboard();
        
        vm.stopBroadcast();
        
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("TVLLeaderboard deployed at:", address(tvlLeaderboard));
        console.log("Owner:", deployer);
        console.log("DEFAULT_ADMIN_ROLE granted to:", deployer);
        console.log("SNAPSHOT_ROLE granted to:", deployer);
        console.log("Current Epoch:", tvlLeaderboard.currentEpoch());
        console.log("Epoch Duration:", tvlLeaderboard.EPOCH_DURATION(), "seconds");
        console.log("Epoch Start Time:", tvlLeaderboard.epochStartTime());
        
        // Verify roles
        require(tvlLeaderboard.hasRole(tvlLeaderboard.DEFAULT_ADMIN_ROLE(), deployer), "Admin role not set");
        require(tvlLeaderboard.hasRole(tvlLeaderboard.SNAPSHOT_ROLE(), deployer), "Snapshot role not set");
        
        console.log("=== ROLE VERIFICATION PASSED ===");
        
        // Save deployment info
        // string memory deploymentInfo = string.concat(
        //     "TVLLeaderboard deployed at: ",
        //     vm.toString(address(tvlLeaderboard)),
        //     "\\nDeployer: ",
        //     vm.toString(deployer),
        //     "\\nNetwork: ",
        //     vm.toString(block.chainid),
        //     "\\nTimestamp: ",
        //     vm.toString(block.timestamp),
        //     "\\nCurrent Epoch: ",
        //     vm.toString(tvlLeaderboard.currentEpoch()),
        //     "\\nEpoch Duration: ",
        //     vm.toString(tvlLeaderboard.EPOCH_DURATION()),
        //     " seconds"
        // );
        
        // vm.writeFile("deployment_tvl_leaderboard.txt", deploymentInfo);
        // console.log("Deployment info saved to: deployment_tvl_leaderboard.txt");
    }
} 