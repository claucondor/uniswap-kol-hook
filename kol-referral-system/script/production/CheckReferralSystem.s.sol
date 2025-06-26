// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";

import {IReferralRegistry} from "../../contracts/interfaces/IReferralRegistry.sol";
import {ReferralHook} from "../../contracts/hooks/ReferralHook.sol";
import {BaseScript} from "../base/BaseScript.sol";

contract CheckReferralSystem is BaseScript {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    // Deployed contract addresses - UPDATED
    address constant REFERRAL_REGISTRY_ADDR = 0xacd17CefE9F105aaa839D802caD0B9BEE1f80F71;
    address constant REFERRAL_HOOK_ADDR = 0x953A5Dd9072a32167D10966B360B68ec33db4500; // NEW HOOK
    address constant KOLTEST1_TOKEN_ADDR = 0x6F22c4b5ec7efAEd0c315a2C7A34FDb25A78f6b1;
    address constant KOLTEST2_TOKEN_ADDR = 0xe13c9298c63912568ed74825625bC7731c64Bc1e;
    
    // Addresses to check
    address constant KOL_ADDRESS = 0xC166C00d5696afb27Cf07671a85b78a589a20A5c;
    address constant USER_ADDRESS = 0xc5c5A0220c1AbFCfA26eEc68e55d9b689193d6b2;
    string constant REFERRAL_CODE = "KOLONE";

    uint24 constant POOL_FEE = 3000;
    int24 constant TICK_SPACING = 60;

    function run() external view {
        console.log("=== REFERRAL SYSTEM DIAGNOSTIC ===");
        console.log("KOL Address:", KOL_ADDRESS);
        console.log("User Address:", USER_ADDRESS);
        console.log("Referral Code:", REFERRAL_CODE);
        console.log("");

        // Get contract instances
        IReferralRegistry registry = IReferralRegistry(REFERRAL_REGISTRY_ADDR);
        ReferralHook hook = ReferralHook(REFERRAL_HOOK_ADDR);

        // Create PoolKey
        Currency currency0;
        Currency currency1;
        
        if (KOLTEST1_TOKEN_ADDR < KOLTEST2_TOKEN_ADDR) {
            currency0 = Currency.wrap(KOLTEST1_TOKEN_ADDR);
            currency1 = Currency.wrap(KOLTEST2_TOKEN_ADDR);
        } else {
            currency0 = Currency.wrap(KOLTEST2_TOKEN_ADDR);
            currency1 = Currency.wrap(KOLTEST1_TOKEN_ADDR);
        }

        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(REFERRAL_HOOK_ADDR)
        });

        PoolId poolId = poolKey.toId();
        console.log("Pool ID:");
        console.logBytes32(PoolId.unwrap(poolId));
        console.log("");

        // 1. Check if KOL is registered
        console.log("=== 1. KOL REGISTRATION CHECK ===");
        try registry.getReferralByCode(REFERRAL_CODE) returns (uint256 tokenId, IReferralRegistry.ReferralInfo memory info) {
            if (tokenId > 0) {
                console.log("KOL registered for code KOLONE:", info.kol);
                console.log("Matches expected KOL:", info.kol == KOL_ADDRESS);
                console.log("Token ID:", tokenId);
                console.log("Is Active:", info.isActive);
            } else {
                console.log("ERROR: No referral found for code KOLONE");
            }
        } catch {
            console.log("ERROR: Could not get referral by code");
        }
        console.log("");

        // 2. Check if user is registered as referred
        console.log("=== 2. USER REFERRAL CHECK ===");
        try registry.getUserReferralInfo(USER_ADDRESS) returns (uint256 tokenId, address kol, string memory code) {
            console.log("User referral info:");
            console.log("  Token ID:", tokenId);
            console.log("  KOL:", kol);
            console.log("  Code:", code);
            console.log("  Is registered:", tokenId > 0);
            console.log("  Correct KOL:", kol == KOL_ADDRESS);
        } catch {
            console.log("ERROR: Could not get user referral info");
        }
        console.log("");

        // 3. Check hook statistics
        console.log("=== 3. HOOK STATISTICS ===");
        try hook.getKOLStats(KOL_ADDRESS) returns (uint256 totalTVL, uint256 uniqueUsers) {
            console.log("KOL stats from hook:");
            console.log("  Total TVL:", totalTVL);
            console.log("  Unique Users:", uniqueUsers);
        } catch {
            console.log("ERROR: Could not get KOL stats from hook");
        }

        try hook.getUserReferrer(poolId, USER_ADDRESS) returns (address referrer) {
            console.log("User referrer in hook for this pool:", referrer);
            console.log("  Is set:", referrer != address(0));
            console.log("  Matches KOL:", referrer == KOL_ADDRESS);
        } catch {
            console.log("ERROR: Could not get user referrer from hook");
        }
        console.log("");

        // 4. Check registry statistics
        console.log("=== 4. REGISTRY STATISTICS ===");
        try registry.getReferralByCode(REFERRAL_CODE) returns (
            uint256 tokenId,
            IReferralRegistry.ReferralInfo memory info
        ) {
            console.log("Referral info from registry:");
            console.log("  Token ID:", tokenId);
            console.log("  KOL:", info.kol);
            console.log("  Total TVL:", info.totalTVL);
            console.log("  Unique Users:", info.uniqueUsers);
            console.log("  Is Active:", info.isActive);
            console.log("  Social Handle:", info.socialHandle);
        } catch {
            console.log("ERROR: Could not get referral info from registry");
        }
        console.log("");

        // 5. Check user token balances
        console.log("=== 5. USER TOKEN BALANCES ===");
        console.log("User KOLTEST1 balance:", IERC20(KOLTEST1_TOKEN_ADDR).balanceOf(USER_ADDRESS));
        console.log("User KOLTEST2 balance:", IERC20(KOLTEST2_TOKEN_ADDR).balanceOf(USER_ADDRESS));
        console.log("");

        // 6. Check pool state
        console.log("=== 6. POOL STATE ===");
        // TODO: Fix pool state reading
        console.log("Pool state check skipped due to interface issues");

        console.log("=== DIAGNOSTIC COMPLETE ===");
    }
} 