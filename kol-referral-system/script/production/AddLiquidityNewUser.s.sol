// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

import {BaseScript} from "../base/BaseScript.sol";

contract AddLiquidityNewUser is BaseScript {
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    // Pool and Token Configuration - UPDATED WITH DEPLOYMENT_SUMMARY.MD ADDRESSES
    address constant KOLTEST1_TOKEN_ADDR = 0x52bc5Caf2520c31a7669A7FAaD0F8E37aF53c5D3;
    address constant KOLTEST2_TOKEN_ADDR = 0xFe3Ad79f52CD53bf8e948A32936d7d5EB53f00a7;
    address constant UPDATED_REFERRAL_HOOK_ADDR = 0x65E6c7be675a3169F90Bb074F19f616772498500; // DEPLOYMENT_SUMMARY.MD HOOK
    
    uint24 constant TARGET_LP_FEE = 3000; // 0.30%
    int24 constant TARGET_TICK_SPACING = 60;

    // Liquidity amounts - 100M of each token
    uint256 public constant TOKEN_AMOUNT = 100_000_000 * 1e18;

    function run() external {
        address liquidityProvider = msg.sender;
        console.log("=== ADD LIQUIDITY (NEW USER) - UPDATED HOOK ===");
        console.log("Liquidity Provider:", liquidityProvider);
        console.log("Using UPDATED Hook:", UPDATED_REFERRAL_HOOK_ADDR);

        // Determine correct token order
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

        // Check initial balances
        console.log("Initial balance Currency0:", IERC20(Currency.unwrap(currency0)).balanceOf(liquidityProvider));
        console.log("Initial balance Currency1:", IERC20(Currency.unwrap(currency1)).balanceOf(liquidityProvider));

        // Create PoolKey with UPDATED hook
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: TARGET_LP_FEE,
            tickSpacing: TARGET_TICK_SPACING,
            hooks: IHooks(UPDATED_REFERRAL_HOOK_ADDR)
        });

        PoolId poolId = poolKey.toId();
        console.log("NEW Pool ID:");
        console.logBytes32(PoolId.unwrap(poolId));

        // Get current pool state
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);
        int24 currentTick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);
        
        console.log("Current sqrtPriceX96:", sqrtPriceX96);
        console.log("Current tick:", currentTick);

        // Define tick range (wide range around current price)
        int24 tickLower = ((currentTick - (1000 * TARGET_TICK_SPACING)) / TARGET_TICK_SPACING) * TARGET_TICK_SPACING;
        int24 tickUpper = ((currentTick + (1000 * TARGET_TICK_SPACING)) / TARGET_TICK_SPACING) * TARGET_TICK_SPACING;
        
        console.log("Tick range - Lower:", tickLower);
        console.log("Tick range - Upper:", tickUpper);

        // Calculate liquidity
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            TOKEN_AMOUNT,
            TOKEN_AMOUNT
        );
        
        console.log("Calculated liquidity:", liquidity);

        // Slippage protection (1% extra)
        uint256 amount0Max = TOKEN_AMOUNT + (TOKEN_AMOUNT / 100);
        uint256 amount1Max = TOKEN_AMOUNT + (TOKEN_AMOUNT / 100);

        vm.startBroadcast();

        // Step 1: Approve tokens to Permit2
        console.log("Approving tokens to Permit2...");
        IERC20(Currency.unwrap(currency0)).approve(address(permit2), type(uint256).max);
        IERC20(Currency.unwrap(currency1)).approve(address(permit2), type(uint256).max);

        // Step 2: Give Permit2 permission to let PositionManager spend tokens
        console.log("Setting Permit2 allowances...");
        permit2.approve(Currency.unwrap(currency0), address(positionManager), type(uint160).max, type(uint48).max);
        permit2.approve(Currency.unwrap(currency1), address(positionManager), type(uint160).max, type(uint48).max);

        // Step 3: Encode Actions (following official docs)
        bytes memory actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION),
            uint8(Actions.SETTLE_PAIR)
        );

        // Step 4: Encode Parameters
        bytes[] memory params = new bytes[](2);

        // IMPORTANT: Pass the actual user address in hookData for proper resolution
        bytes memory hookData = abi.encode(liquidityProvider);
        console.log("Passing user in hookData for hook resolution:", liquidityProvider);

        // Parameters for MINT_POSITION
        params[0] = abi.encode(
            poolKey,        // PoolKey
            tickLower,      // int24 tickLower
            tickUpper,      // int24 tickUpper  
            liquidity,      // uint256 liquidity
            amount0Max,     // uint128 amount0Max
            amount1Max,     // uint128 amount1Max
            liquidityProvider, // address recipient
            hookData        // bytes hookData - CONTAINS USER ADDRESS
        );

        // Parameters for SETTLE_PAIR
        params[1] = abi.encode(currency0, currency1);

        // Step 5: Execute the mint operation
        uint256 deadline = block.timestamp + 120;
        
        console.log("Executing mint position with user resolution...");
        positionManager.modifyLiquidities(
            abi.encode(actions, params),
            deadline
        );

        vm.stopBroadcast();

        // Check final balances
        console.log("Final balance Currency0:", IERC20(Currency.unwrap(currency0)).balanceOf(liquidityProvider));
        console.log("Final balance Currency1:", IERC20(Currency.unwrap(currency1)).balanceOf(liquidityProvider));
        
        console.log("=== LIQUIDITY ADDED WITH UPDATED HOOK - CHECK REFERRAL TRACKING! ===");
    }
} 