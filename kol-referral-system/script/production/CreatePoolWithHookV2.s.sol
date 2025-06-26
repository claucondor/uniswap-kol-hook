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

contract CreatePoolWithHookV2 is BaseScript {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    function run() external {
        console.log("=== CREATE POOL WITH UPDATED HOOK V2 ===");
        
        // Pool configuration with UPDATED hook
        address token0 = 0x52bc5Caf2520c31a7669A7FAaD0F8E37aF53c5D3; // KOLTEST1 (FINAL)
        address token1 = 0xFe3Ad79f52CD53bf8e948A32936d7d5EB53f00a7; // KOLTEST2 (FINAL)
        uint24 fee = 3000; // 0.30%
        int24 tickSpacing = 60;
        address hookAddress = 0x65E6c7be675a3169F90Bb074F19f616772498500; // ReferralHook (FINAL)
        
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
        
        console.log("Creating pool with UPDATED hook:");
        console.log("Currency0:", token0);
        console.log("Currency1:", token1);
        console.log("Fee:", fee);
        console.log("Tick Spacing:", tickSpacing);
        console.log("NEW Hook:", hookAddress);
        console.log("Initial Price (sqrtPriceX96):", sqrtPriceX96);
        
        vm.startBroadcast();
        
        // Initialize the pool
        poolManager.initialize(poolKey, sqrtPriceX96);
        
        vm.stopBroadcast();
        
        PoolId poolId = poolKey.toId();
        console.log("NEW Pool created successfully with updated hook!");
        console.log("NEW PoolId:");
        console.logBytes32(PoolId.unwrap(poolId));
        
        console.log("=== IMPORTANT: UPDATE YOUR SCRIPTS TO USE THE NEW POOL ===");
    }
} 