// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TestToken18} from "../../contracts/mocks/TestToken18.sol";

contract DeployKOLTestTokens is Script {
    
    // Backend address to receive all tokens
    address constant BACKEND_ADDRESS = 0xc5c5A0220c1AbFCfA26eEc68e55d9b689193d6b2;
    
    // Initial supply for each token (1 million tokens with 18 decimals)
    uint256 constant INITIAL_SUPPLY = 1_000_000 * 10**18;
    
    function run() external {
        // Get deployer from private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Deploying KOL Test Tokens ===");
        console.log("Deployer:", deployer);
        console.log("Backend Address:", BACKEND_ADDRESS);
        console.log("Initial Supply per token:", INITIAL_SUPPLY);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy KOLTEST1
        console.log("\n--- Deploying KOLTEST1 ---");
        TestToken18 kolTest1 = new TestToken18(
            "KOLTEST1",
            "KOLTEST1", 
            INITIAL_SUPPLY
        );
        console.log("KOLTEST1 deployed at:", address(kolTest1));
        
        // Deploy KOLTEST2
        console.log("\n--- Deploying KOLTEST2 ---");
        TestToken18 kolTest2 = new TestToken18(
            "KOLTEST2",
            "KOLTEST2",
            INITIAL_SUPPLY
        );
        console.log("KOLTEST2 deployed at:", address(kolTest2));
        
        // Transfer all KOLTEST1 tokens to backend
        console.log("\n--- Transferring KOLTEST1 to backend ---");
        uint256 balance1 = kolTest1.balanceOf(deployer);
        console.log("KOLTEST1 balance to transfer:", balance1);
        kolTest1.transfer(BACKEND_ADDRESS, balance1);
        console.log("KOLTEST1 transferred successfully");
        
        // Transfer all KOLTEST2 tokens to backend
        console.log("\n--- Transferring KOLTEST2 to backend ---");
        uint256 balance2 = kolTest2.balanceOf(deployer);
        console.log("KOLTEST2 balance to transfer:", balance2);
        kolTest2.transfer(BACKEND_ADDRESS, balance2);
        console.log("KOLTEST2 transferred successfully");
        
        vm.stopBroadcast();
        
        // Verify final balances
        console.log("\n=== Final Verification ===");
        console.log("KOLTEST1 backend balance:", kolTest1.balanceOf(BACKEND_ADDRESS));
        console.log("KOLTEST2 backend balance:", kolTest2.balanceOf(BACKEND_ADDRESS));
        console.log("KOLTEST1 deployer balance:", kolTest1.balanceOf(deployer));
        console.log("KOLTEST2 deployer balance:", kolTest2.balanceOf(deployer));
        
        console.log("\n=== Deployment Summary ===");
        console.log("KOLTEST1:", address(kolTest1));
        console.log("KOLTEST2:", address(kolTest2));
        console.log("Backend Address:", BACKEND_ADDRESS);
        console.log("Tokens per contract:", INITIAL_SUPPLY);
    }
} 