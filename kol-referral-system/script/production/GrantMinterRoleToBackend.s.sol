// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
// We don't strictly need to import ReferralRegistry if we calculate the role hash directly
// import {ReferralRegistry} from "../../contracts/core/ReferralRegistry.sol"; 
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract GrantMinterRoleToBackend is Script {
    // Address of the ReferralRegistry contract
    address constant REFERRAL_REGISTRY_ADDR = 0xacd17CefE9F105aaa839D802caD0B9BEE1f80F71;
    
    // Address of the backend wallet to grant MINTER_ROLE
    address constant BACKEND_WALLET_ADDR = 0xdEe6A277620687e77dE63Ddfa2528BC882360343;

    function run() external {
        console.log("=== Granting MINTER_ROLE to Backend Wallet ===");

        // Read PRIVATE_KEY from .env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY"); 
        if (deployerPrivateKey == 0) {
            console.log("ERROR: PRIVATE_KEY not found in .env file. Aborting.");
            return;
        }
        
        // Calculate the role hash directly
        bytes32 minterRole = keccak256(bytes("MINTER_ROLE"));

        console.log("Target ReferralRegistry:", REFERRAL_REGISTRY_ADDR);
        console.log("Backend Wallet to grant role:", BACKEND_WALLET_ADDR);
        console.logString("MINTER_ROLE hash (calculated):");
        console.logBytes32(minterRole);
        
        vm.startBroadcast(deployerPrivateKey);

        AccessControl registry = AccessControl(payable(REFERRAL_REGISTRY_ADDR));
        
        if (registry.hasRole(minterRole, BACKEND_WALLET_ADDR)) {
            console.log("INFO: MINTER_ROLE already granted to backend wallet. No action taken.");
        } else {
            registry.grantRole(minterRole, BACKEND_WALLET_ADDR);
            console.log("INFO: Successfully called grantRole.");
        }

        vm.stopBroadcast();

        bool hasRoleNow = registry.hasRole(minterRole, BACKEND_WALLET_ADDR);
        console.log("Verification: Backend wallet has MINTER_ROLE:", hasRoleNow);

        if (hasRoleNow) {
            console.log("SUCCESS: MINTER_ROLE successfully granted/confirmed for backend wallet.");
        } else {
            console.log("FAILURE: Failed to grant MINTER_ROLE or verification failed.");
        }
        console.log("===============================================");
    }
} 