// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
// No necesitamos las interfaces completas aquí si vamos a castear a AccessControl
// import {IReferralRegistry} from "../../contracts/interfaces/IReferralRegistry.sol";
// import {ITVLLeaderboard} from "../../contracts/interfaces/ITVLLeaderboard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract GrantRolesToHook is Script {
    // --- Deployed Contract Addresses ---
    address private constant REFERRAL_HOOK_ADDRESS = 0x953A5Dd9072a32167D10966B360B68ec33db4500;
    address private constant REFERRAL_REGISTRY_ADDRESS = 0xacd17CefE9F105aaa839D802caD0B9BEE1f80F71;
    address private constant TVL_LEADERBOARD_ADDRESS = 0x4839d26Aee01ffcC3bB432Cbc8024A9a388873ba;

    // Role definitions (keccak256 of the role string)
    bytes32 private constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    bytes32 private constant HOOK_ROLE = keccak256("HOOK_ROLE");

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address adminAddress = vm.addr(deployerPrivateKey);

        console.log("=== GRANTING ROLES TO REFERRAL HOOK ===");
        console.log("Admin Account (Granting Roles):", adminAddress);
        console.log("Target Hook Address:", REFERRAL_HOOK_ADDRESS);
        console.log("ReferralRegistry Address:", REFERRAL_REGISTRY_ADDRESS);
        console.log("TVLLeaderboard Address:", TVL_LEADERBOARD_ADDRESS);

        vm.startBroadcast(deployerPrivateKey);

        // --- Grant UPDATER_ROLE on ReferralRegistry to ReferralHook ---
        console.log("Attempting to grant UPDATER_ROLE (", vm.toString(UPDATER_ROLE), ") on ReferralRegistry...");
        AccessControl(payable(REFERRAL_REGISTRY_ADDRESS)).grantRole(UPDATER_ROLE, REFERRAL_HOOK_ADDRESS);
        console.log("UPDATER_ROLE granted to Hook on ReferralRegistry.");

        // --- Grant HOOK_ROLE on TVLLeaderboard to ReferralHook ---
        console.log("Attempting to grant HOOK_ROLE (", vm.toString(HOOK_ROLE), ") on TVLLeaderboard...");
        AccessControl(payable(TVL_LEADERBOARD_ADDRESS)).grantRole(HOOK_ROLE, REFERRAL_HOOK_ADDRESS);
        console.log("HOOK_ROLE granted to Hook on TVLLeaderboard.");

        vm.stopBroadcast();

        console.log("=== ROLE GRANTING COMPLETE ===");

        // --- Verification ---
        console.log("Verifying roles...");
        bool hasUpdaterRole = AccessControl(payable(REFERRAL_REGISTRY_ADDRESS)).hasRole(UPDATER_ROLE, REFERRAL_HOOK_ADDRESS);
        console.log("Hook has UPDATER_ROLE on ReferralRegistry:", vm.toString(hasUpdaterRole));
        require(hasUpdaterRole, "Verification Failed: Hook does not have UPDATER_ROLE on ReferralRegistry");

        bool hasHookRoleOnLeaderboard = AccessControl(payable(TVL_LEADERBOARD_ADDRESS)).hasRole(HOOK_ROLE, REFERRAL_HOOK_ADDRESS);
        console.log("Hook has HOOK_ROLE on TVLLeaderboard:", vm.toString(hasHookRoleOnLeaderboard));
        require(hasHookRoleOnLeaderboard, "Verification Failed: Hook does not have HOOK_ROLE on TVLLeaderboard");

        console.log("All roles successfully granted and verified.");
    }
} 