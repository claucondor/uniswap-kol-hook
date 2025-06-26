// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {BaseScript} from "../base/BaseScript.sol";

contract ReadPoolState is BaseScript {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    // Pool parameters from our created pool (UPDATED)
    address constant KOLTEST1 = 0x52bc5Caf2520c31a7669A7FAaD0F8E37aF53c5D3;
    address constant KOLTEST2 = 0xFe3Ad79f52CD53bf8e948A32936d7d5EB53f00a7;
    address constant CURRENT_HOOK = 0x65E6c7be675a3169F90Bb074F19f616772498500;
    uint24 constant FEE = 3000;
    int24 constant TICK_SPACING = 60;

    function run() external view {
        // Create the pool key
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(KOLTEST1),
            currency1: Currency.wrap(KOLTEST2),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(CURRENT_HOOK)
        });

        PoolId poolId = key.toId();
        console.log("Reading state for Pool ID:");
        console.logBytes32(PoolId.unwrap(poolId));

        // Read pool state using StateLibrary
        (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) = poolManager.getSlot0(poolId);
        
        console.log("\n=== Pool State ===");
        console.log("sqrtPriceX96:", sqrtPriceX96);
        console.log("Current tick:", tick);
        console.log("Protocol fee:", protocolFee);
        console.log("LP fee:", lpFee);
        
        // Calculate approximate price (price = (sqrtPriceX96 / 2^96)^2)
        if (sqrtPriceX96 > 0) {
            console.log("Pool is initialized with price data");
        } else {
            console.log("Pool is not initialized yet");
        }

        // Read liquidity
        uint128 liquidity = poolManager.getLiquidity(poolId);
        console.log("\n=== Liquidity ===");
        console.log("Total liquidity:", liquidity);

        // Note: getFeeGrowthGlobal is not available in IPoolManager interface
        // This would require direct storage reading using extsload
        console.log("\n=== Pool Analysis Complete ===");
        if (sqrtPriceX96 > 0 && liquidity > 0) {
            console.log("Pool is active with liquidity and price data");
        } else if (sqrtPriceX96 > 0) {
            console.log("Pool is initialized but has no liquidity");
        } else {
            console.log("Pool exists but is not initialized");
        }
    }
} 