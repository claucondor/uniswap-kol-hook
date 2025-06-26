// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IReferralRegistry} from "../../contracts/interfaces/IReferralRegistry.sol";
import {BaseScript} from "../base/BaseScript.sol"; // Inherited for consistency

contract RegisterReferredUser is BaseScript {
    // Correct address of the deployed ReferralRegistry from deployment_addresses.txt
    address constant CORRECT_REFERRAL_REGISTRY_ADDRESS = 0xacd17CefE9F105aaa839D802caD0B9BEE1f80F71;
    string constant KOL_REFERRAL_CODE_TO_USE = "KOLONE";

    function run() external {
        // This script must be run with the NEW_USER_PRIVATE_KEY.
        // msg.sender will then be the address of the new user.
        address newUserAddress = msg.sender; 
        
        console.log("=== REGISTERING REFERRED USER ===");
        console.log("New User Address (msg.sender):", newUserAddress);
        console.log("Attempting to use referral code:", KOL_REFERRAL_CODE_TO_USE);
        console.log("Target ReferralRegistry:", CORRECT_REFERRAL_REGISTRY_ADDRESS);
        // deployerAddress from BaseScript.setUp() is derived from PRIVATE_KEY env var.
        // It's logged here for reference but not necessarily the signer of *this* transaction 
        // if --private-key flag for forge script points to NEW_USER_PRIVATE_KEY.
        console.log("BaseScript deployerAddress (for reference):", deployerAddress);

        vm.startBroadcast(); // This will use the private key specified by --private-key in the forge command

        IReferralRegistry referralRegistry = IReferralRegistry(CORRECT_REFERRAL_REGISTRY_ADDRESS);

        console.log("Calling setUserReferral for user:", newUserAddress, "with code:", KOL_REFERRAL_CODE_TO_USE);
        (uint256 referredTokenId, address referredKol) = referralRegistry.setUserReferral(
            newUserAddress, // User to refer is the one executing the script
            KOL_REFERRAL_CODE_TO_USE
        );

        vm.stopBroadcast();

        console.log("=== USER REFERRAL SUCCESS! ===");
        console.log("New User Address:", newUserAddress);
        console.log("Successfully referred using code:", KOL_REFERRAL_CODE_TO_USE);
        console.log("Referred by KOL with Token ID:", referredTokenId);
        console.log("Referred by KOL Address:", referredKol);
        
        // Verification step
        console.log("Verifying registration details...");
        (uint256 tokenIdCheck, address kolCheck, string memory codeCheck) = referralRegistry.getUserReferralInfo(newUserAddress);
        
        console.log("Retrieved Token ID for user:", tokenIdCheck);
        console.log("Retrieved KOL Address for user:", kolCheck);
        console.log("Retrieved Referral Code for user:", codeCheck);

        require(tokenIdCheck == referredTokenId, "Verification Error: Token ID mismatch after registration");
        require(kolCheck == referredKol, "Verification Error: KOL address mismatch after registration");
        require(keccak256(abi.encodePacked(codeCheck)) == keccak256(abi.encodePacked(KOL_REFERRAL_CODE_TO_USE)), "Verification Error: Referral code mismatch after registration");
        
        console.log("Verification successful: User", newUserAddress, "is now correctly registered with referral code", codeCheck);
    }
} 