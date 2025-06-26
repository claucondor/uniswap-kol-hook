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

    // Pool and Token Configuration from deployment_addresses.txt
    address constant KOLTEST1_TOKEN_ADDR = 0x6F22c4b5ec7efAEd0c315a2C7A34FDb25A78f6b1;
    address constant KOLTEST2_TOKEN_ADDR = 0xe13c9298c63912568ed74825625bC7731c64Bc1e;
    address constant ACTIVE_REFERRAL_HOOK_ADDR = 0x52e053acd5d8Bf354d3C1eFFacE357F4F1410500;
    
    uint24 constant TARGET_LP_FEE = 3000; // 0.30%
    int24 constant TARGET_TICK_SPACING = 60;

    // Liquidity amounts - 100M of each token
    uint256 public constant TOKEN_AMOUNT = 100_000_000 * 1e18;

    function run() external {
        address liquidityProvider = msg.sender;
        console.log("=== ADD LIQUIDITY (NEW USER) ===");
        console.log("Liquidity Provider:", liquidityProvider);

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

        // Create PoolKey
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: TARGET_LP_FEE,
            tickSpacing: TARGET_TICK_SPACING,
            hooks: IHooks(ACTIVE_REFERRAL_HOOK_ADDR)
        });

        // Get current pool state
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolKey.toId());
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

        // Parameters for MINT_POSITION
        params[0] = abi.encode(
            poolKey,        // PoolKey
            tickLower,      // int24 tickLower
            tickUpper,      // int24 tickUpper  
            liquidity,      // uint256 liquidity
            amount0Max,     // uint128 amount0Max
            amount1Max,     // uint128 amount1Max
            liquidityProvider, // address recipient
            ""              // bytes hookData
        );

        // Parameters for SETTLE_PAIR
        params[1] = abi.encode(currency0, currency1);

        // Step 5: Execute the mint operation
        uint256 deadline = block.timestamp + 120;
        
        console.log("Executing mint position...");
        positionManager.modifyLiquidities(
            abi.encode(actions, params),
            deadline
        );

        vm.stopBroadcast();

        // Check final balances
        console.log("Final balance Currency0:", IERC20(Currency.unwrap(currency0)).balanceOf(liquidityProvider));
        console.log("Final balance Currency1:", IERC20(Currency.unwrap(currency1)).balanceOf(liquidityProvider));
        
        console.log("=== LIQUIDITY ADDED SUCCESSFULLY ===");
    }
} 