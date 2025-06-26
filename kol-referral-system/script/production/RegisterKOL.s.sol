// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IReferralRegistry} from "../../contracts/interfaces/IReferralRegistry.sol";
import {BaseScript} from "../base/BaseScript.sol";

contract RegisterKOL is BaseScript {
    // Address of the deployed ReferralRegistry contract
    // IMPORTANT: Make sure this address is correct and matches your deployment_addresses.txt
    address constant REFERRAL_REGISTRY_ADDRESS = 0xacd17CefE9F105aaa839D802caD0B9BEE1f80F71;

    // KOL Details
    address constant KOL_ADDRESS = 0xC166C00d5696afb27Cf07671a85b78a589a20A5c;
    string constant REFERRAL_CODE = "KOLONE";
    string constant SOCIAL_HANDLE = "KOL_SOCIAL_1";
    string constant METADATA_URI = "ipfs://kol_one_metadata_placeholder";

    function run() external {
        vm.startBroadcast();

        IReferralRegistry referralRegistry = IReferralRegistry(REFERRAL_REGISTRY_ADDRESS);

        console.log("=== REGISTERING KOL ===");
        console.log("KOL Address:", KOL_ADDRESS);
        console.log("Referral Code:", REFERRAL_CODE);
        console.log("Social Handle:", SOCIAL_HANDLE);
        console.log("Using ReferralRegistry at:", address(referralRegistry));
        console.log("Deployer (should have MINTER_ROLE):", deployerAddress);

        uint256 newTokenId = referralRegistry.mintReferral(
            KOL_ADDRESS,
            REFERRAL_CODE,
            SOCIAL_HANDLE,
            METADATA_URI
        );

        console.log("\n=== SUCCESS! ===");
        console.log("KOL NFT minted successfully!");
        console.log("Token ID:", newTokenId);
        console.log("KOL can now use referral code:", REFERRAL_CODE);

        vm.stopBroadcast();
    }
} 