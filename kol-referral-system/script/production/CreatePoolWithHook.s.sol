// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

import {BaseScript} from "../base/BaseScript.sol";

contract CreatePoolWithHook is BaseScript {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    function run() external {
        console.log("=== CREATE POOL WITH HOOK ===");
        
        // COMMENTED OUT PROBLEMATIC LINES TO ALLOW COMPILATION
        // IPoolManager.Slot0 memory testSlot0;
        // IPoolManager.PoolParameters memory testParams;
        
        // Pool configuration
        address token0 = 0x6F22c4b5ec7efAEd0c315a2C7A34FDb25A78f6b1; // KOLTEST1
        address token1 = 0xe13c9298c63912568ed74825625bC7731c64Bc1e; // KOLTEST2
        uint24 fee = 3000; // 0.30%
        int24 tickSpacing = 60;
        address hookAddress = 0x52e053acd5d8Bf354d3C1eFFacE357F4F1410500; // ReferralHook
        
        // Ensure correct token order
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        
        Currency currency0 = Currency.wrap(token0);
        Currency currency1 = Currency.wrap(token1);
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hookAddress)
        });
        
        // Calculate initial price (1:1 ratio)
        uint160 sqrtPriceX96 = 79228162514264337593543950336; // sqrt(1) * 2^96
        
        console.log("Creating pool with:");
        console.log("Currency0:", token0);
        console.log("Currency1:", token1);
        console.log("Fee:", fee);
        console.log("Tick Spacing:", tickSpacing);
        console.log("Hook:", hookAddress);
        console.log("Initial Price (sqrtPriceX96):", sqrtPriceX96);
        
        vm.startBroadcast();
        
        // Initialize the pool
        poolManager.initialize(poolKey, sqrtPriceX96, "");
        
        vm.stopBroadcast();
        
        PoolId poolId = poolKey.toId();
        console.log("Pool created successfully!");
        console.log("PoolId:");
        console.logBytes32(PoolId.unwrap(poolId));
    }
} 