// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IReferralRegistry} from "../../contracts/interfaces/IReferralRegistry.sol";

contract CheckRoles is Script {
    address constant REFERRAL_REGISTRY_ADDRESS = 0xacd17CefE9F105aaa839D802caD0B9BEE1f80F71;
    
    // Common addresses to check
    address constant DEPLOYER = 0x2F2B1a3648C58CF224aA69A4B0BdC942F000045F;
    address constant SCRIPT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    
    function run() external view {
        IReferralRegistry registry = IReferralRegistry(REFERRAL_REGISTRY_ADDRESS);
        
        bytes32 minterRole = keccak256("MINTER_ROLE");
        bytes32 adminRole = registry.DEFAULT_ADMIN_ROLE();
        
        console.log("=== ROLE CHECK ===");
        console.log("ReferralRegistry:", address(registry));
        console.log("MINTER_ROLE hash:", vm.toString(minterRole));
        console.log("DEFAULT_ADMIN_ROLE hash:", vm.toString(adminRole));
        
        console.log("\n=== CHECKING DEPLOYER ===");
        console.log("Address:", DEPLOYER);
        console.log("Has MINTER_ROLE:", registry.hasRole(minterRole, DEPLOYER));
        console.log("Has DEFAULT_ADMIN_ROLE:", registry.hasRole(adminRole, DEPLOYER));
        
        console.log("\n=== CHECKING SCRIPT SENDER ===");
        console.log("Address:", SCRIPT_SENDER);
        console.log("Has MINTER_ROLE:", registry.hasRole(minterRole, SCRIPT_SENDER));
        console.log("Has DEFAULT_ADMIN_ROLE:", registry.hasRole(adminRole, SCRIPT_SENDER));
    }
} 