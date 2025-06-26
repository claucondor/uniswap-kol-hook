// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IReferralRegistry} from "../../contracts/interfaces/IReferralRegistry.sol";
import {BaseScript} from "../base/BaseScript.sol";

contract GrantMinterRole is BaseScript {
    address constant REFERRAL_REGISTRY_ADDRESS = 0xacd17CefE9F105aaa839D802caD0B9BEE1f80F71;
    address constant SCRIPT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    
    function run() external {
        vm.startBroadcast();
        
        IReferralRegistry registry = IReferralRegistry(REFERRAL_REGISTRY_ADDRESS);
        bytes32 minterRole = keccak256("MINTER_ROLE");
        
        console.log("=== GRANTING MINTER ROLE ===");
        console.log("Registry:", address(registry));
        console.log("Granting MINTER_ROLE to:", SCRIPT_SENDER);
        console.log("Transaction sender (should have admin):", deployerAddress);
        
        // Grant MINTER_ROLE to the script sender
        registry.grantRole(minterRole, SCRIPT_SENDER);
        
        console.log("SUCCESS: MINTER_ROLE granted successfully!");
        
        vm.stopBroadcast();
    }
} 