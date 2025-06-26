// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/Script.sol";
import {Script} from "forge-std/Script.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

contract CalculatePoolId is Script {
    using PoolIdLibrary for PoolKey;

    function run() external view {
        console.log("=== CALCULATE POOL ID ===");
        
        // Addresses from deployment_summary.md
        address token0 = 0x52bc5Caf2520c31a7669A7FAaD0F8E37aF53c5D3; // KOLTEST1
        address token1 = 0xFe3Ad79f52CD53bf8e948A32936d7d5EB53f00a7; // KOLTEST2
        uint24 fee = 3000; // 0.30%
        int24 tickSpacing = 60;
        address hookAddress = 0x65E6c7be675a3169F90Bb074F19f616772498500; // ReferralHook
        
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
        
        PoolId poolId = poolKey.toId();
        
        console.log("=== DEPLOYMENT_SUMMARY.MD ADDRESSES ===");
        console.log("Currency0:", Currency.unwrap(currency0));
        console.log("Currency1:", Currency.unwrap(currency1));
        console.log("Fee:", fee);
        console.log("Tick Spacing:", tickSpacing);
        console.log("Hook:", hookAddress);
        console.log("=== CALCULATED POOL ID ===");
        console.logBytes32(PoolId.unwrap(poolId));
    }
} 