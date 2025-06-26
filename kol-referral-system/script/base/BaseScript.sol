// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// Permit2 interface - basic functions we need
interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

contract BaseScript is Script {
    using CurrencyLibrary for Currency;
    
    // Base mainnet addresses
    IPoolManager public constant poolManager = IPoolManager(0x498581fF718922c3f8e6A244956aF099B2652b2b);
    IPositionManager public constant positionManager = IPositionManager(0x7C5f5A4bBd8fD63184577525326123B519429bDc);
    
    // Permit2 contract address on Base mainnet
    IPermit2 public constant permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    
    // Our deployed contracts
    address public constant REFERRAL_REGISTRY = 0x205C50E7888Fdb01E289B32DcB00152e41706Fb5;
    address public constant TVL_LEADERBOARD = 0xa1375888DC41f791d4d52ffe536809Ac2C1C9116;
    address public constant REFERRAL_HOOK = 0xD6ADeBcdDeC37E43aB390B67f5D6CCC278F1c500; // Hook V2
    
    // Test tokens
    IERC20 public constant token0 = IERC20(0x8FeC0dA0Adb7Aab466cFa9a463c87682AC7992Ca); // TEST_USDC
    IERC20 public constant token1 = IERC20(0xFAd83621dd9f7564Ab9497E50A6A9ce241061680); // KOL_TOKEN
    
    // Currencies for pool creation
    Currency public currency0;
    Currency public currency1;
    IHooks public hookContract;
    address public deployerAddress;

    function setUp() public virtual {
        deployerAddress = vm.addr(vm.envUint("PRIVATE_KEY"));
        
        // Set up currencies (ensure correct ordering)
        if (address(token0) < address(token1)) {
            currency0 = Currency.wrap(address(token0));
            currency1 = Currency.wrap(address(token1));
        } else {
            currency0 = Currency.wrap(address(token1));
            currency1 = Currency.wrap(address(token0));
        }
        
        hookContract = IHooks(REFERRAL_HOOK);
        
        console.log("=== BASE SCRIPT SETUP ===");
        console.log("Deployer:", deployerAddress);
        console.log("Currency0:", Currency.unwrap(currency0));
        console.log("Currency1:", Currency.unwrap(currency1));
        console.log("Hook:", address(hookContract));
    }

    function tokenApprovals() internal {
        // Step 1: Approve tokens to Permit2 (standard ERC20 approval)
        if (!currency0.isAddressZero()) {
            IERC20(Currency.unwrap(currency0)).approve(address(permit2), type(uint256).max);
            // Step 2: Give Permit2 permission to let PositionManager spend tokens
            permit2.approve(Currency.unwrap(currency0), address(positionManager), type(uint160).max, type(uint48).max);
        }

        if (!currency1.isAddressZero()) {
            IERC20(Currency.unwrap(currency1)).approve(address(permit2), type(uint256).max);
            // Step 2: Give Permit2 permission to let PositionManager spend tokens
            permit2.approve(Currency.unwrap(currency1), address(positionManager), type(uint160).max, type(uint48).max);
        }
        
        console.log("Token approvals granted to Permit2 and PositionManager");
        console.log("Permit2 address:", address(permit2));
    }
} 