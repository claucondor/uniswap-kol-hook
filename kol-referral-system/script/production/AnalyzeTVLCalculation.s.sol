// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

import {BaseScript} from "../base/BaseScript.sol";
import {ReferralHook} from "../../contracts/hooks/ReferralHook.sol";

contract AnalyzeTVLCalculation is BaseScript {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    // UPDATED ADDRESSES FROM DEPLOYMENT_SUMMARY.MD
    address constant KOLTEST1_TOKEN_ADDR = 0x52bc5Caf2520c31a7669A7FAaD0F8E37aF53c5D3;
    address constant KOLTEST2_TOKEN_ADDR = 0xFe3Ad79f52CD53bf8e948A32936d7d5EB53f00a7;
    address constant REFERRAL_HOOK_ADDR = 0x65E6c7be675a3169F90Bb074F19f616772498500;
    
    // Users
    address constant KOL_ADDRESS = 0xC166C00d5696afb27Cf07671a85b78a589a20A5c;
    address constant REFERRED_USER = 0xc5c5A0220c1AbFCfA26eEc68e55d9b689193d6b2;
    
    uint24 constant TARGET_LP_FEE = 3000;
    int24 constant TARGET_TICK_SPACING = 60;

    function run() external view {
        console.log("=== TVL CALCULATION ANALYSIS (UPDATED ADDRESSES) ===");
        console.log("KOLTEST1:", KOLTEST1_TOKEN_ADDR);
        console.log("KOLTEST2:", KOLTEST2_TOKEN_ADDR);
        console.log("ReferralHook:", REFERRAL_HOOK_ADDR);
        console.log("");
        
        // Create the pool key
        Currency currency0;
        Currency currency1;
        
        if (KOLTEST1_TOKEN_ADDR < KOLTEST2_TOKEN_ADDR) {
            currency0 = Currency.wrap(KOLTEST1_TOKEN_ADDR);
            currency1 = Currency.wrap(KOLTEST2_TOKEN_ADDR);
            console.log("Currency0 (KOLTEST1):", KOLTEST1_TOKEN_ADDR);
            console.log("Currency1 (KOLTEST2):", KOLTEST2_TOKEN_ADDR);
        } else {
            currency0 = Currency.wrap(KOLTEST2_TOKEN_ADDR);
            currency1 = Currency.wrap(KOLTEST1_TOKEN_ADDR);
            console.log("Currency0 (KOLTEST2):", KOLTEST2_TOKEN_ADDR);
            console.log("Currency1 (KOLTEST1):", KOLTEST1_TOKEN_ADDR);
        }

        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: TARGET_LP_FEE,
            tickSpacing: TARGET_TICK_SPACING,
            hooks: IHooks(REFERRAL_HOOK_ADDR)
        });

        PoolId poolId = poolKey.toId();
        console.log("Pool ID:");
        console.logBytes32(PoolId.unwrap(poolId));
        console.log("");

        // Get hook instance
        ReferralHook hook = ReferralHook(REFERRAL_HOOK_ADDR);
        
        // Get KOL stats from hook
        console.log("=== KOL STATS FROM HOOK ===");
        try hook.getKOLStats(KOL_ADDRESS) returns (uint256 kolTotalTVL, uint256 kolUniqueUsers) {
            console.log("KOL Address:", KOL_ADDRESS);
            console.log("Total TVL:", kolTotalTVL);
            console.log("Unique Users:", kolUniqueUsers);
            
            // Analyze TVL calculation
            console.log("=== TVL CALCULATION ANALYSIS ===");
            console.log("Expected: 100M + 100M = 200M tokens");
            console.log("Actual TVL:", kolTotalTVL);
            if (kolTotalTVL > 200_000_000 * 1e18) {
                console.log("Difference (over expected):", kolTotalTVL - (200_000_000 * 1e18));
            } else {
                console.log("Difference (under expected):", (200_000_000 * 1e18) - kolTotalTVL);
            }
        } catch {
            console.log("ERROR: Could not get KOL stats from hook");
        }
        
        // Check user referrer
        console.log("=== USER REFERRER CHECK ===");
        try hook.getUserReferrer(poolId, REFERRED_USER) returns (address userReferrer) {
            console.log("User:", REFERRED_USER);
            console.log("Referrer:", userReferrer);
            console.log("Matches KOL:", userReferrer == KOL_ADDRESS);
        } catch {
            console.log("ERROR: Could not get user referrer from hook");
        }
        
        // Explain the calculation
        console.log("=== EXPLANATION ===");
        console.log("The hook's _calculateTVL function does:");
        console.log("1. Takes BalanceDelta (amount0, amount1)");
        console.log("2. Adds absolute values: |amount0| + |amount1|");
        console.log("3. This gives total value of both tokens");
        console.log("");
        console.log("If user added 100M of each token:");
        console.log("- amount0 = 100M tokens");
        console.log("- amount1 = 100M tokens");
        console.log("- TVL = |100M| + |100M| = 200M tokens");
        console.log("");
        
        // Check token balances to verify
        console.log("=== TOKEN BALANCE VERIFICATION ===");
        uint256 user_balance_0 = IERC20(Currency.unwrap(currency0)).balanceOf(REFERRED_USER);
        uint256 user_balance_1 = IERC20(Currency.unwrap(currency1)).balanceOf(REFERRED_USER);
        
        console.log("User current balance currency0:", user_balance_0);
        console.log("User current balance currency1:", user_balance_1);
        
        // Original distribution was 500M each (from deployment_summary.md)
        uint256 original_distribution = 500_000_000 * 1e18;
        uint256 spent_0 = user_balance_0 < original_distribution ? original_distribution - user_balance_0 : 0;
        uint256 spent_1 = user_balance_1 < original_distribution ? original_distribution - user_balance_1 : 0;
        
        console.log("=== ACTUAL SPENDING ANALYSIS ===");
        console.log("Original distribution per token: 500M");
        console.log("Currency0 spent:", spent_0);
        console.log("Currency1 spent:", spent_1);
        console.log("Total tokens spent:", spent_0 + spent_1);
        
        // Get TVL again for final comparison
        try hook.getKOLStats(KOL_ADDRESS) returns (uint256 kolTotalTVL, uint256) {
            if (spent_0 + spent_1 == kolTotalTVL) {
                console.log("SUCCESS: TVL calculation is CORRECT!");
                console.log("TVL = tokens spent in liquidity provision");
            } else {
                console.log("TVL from hook:", kolTotalTVL);
                console.log("Calculated spent:", spent_0 + spent_1);
                console.log("Difference:", kolTotalTVL > (spent_0 + spent_1) ? kolTotalTVL - (spent_0 + spent_1) : (spent_0 + spent_1) - kolTotalTVL);
                if (kolTotalTVL > (spent_0 + spent_1)) {
                    console.log("TVL is HIGHER than expected - possible reasons:");
                    console.log("1. Multiple liquidity additions");
                    console.log("2. Price impact calculations");
                    console.log("3. Additional transactions not accounted for");
                } else if (kolTotalTVL < (spent_0 + spent_1)) {
                    console.log("TVL is LOWER than expected - possible reasons:");
                    console.log("1. Some liquidity was removed");
                    console.log("2. TVL calculation uses different method");
                    console.log("3. Not all transactions were tracked");
                }
            }
        } catch {
            console.log("ERROR: Could not get final TVL for comparison");
        }
    }
} 