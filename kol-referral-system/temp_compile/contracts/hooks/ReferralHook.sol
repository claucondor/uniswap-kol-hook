// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "../interfaces/IReferralRegistry.sol";
import "../interfaces/ITVLLeaderboard.sol";

contract ReferralHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    using FixedPointMathLib for uint256;
    
    // Contratos principales
    IReferralRegistry public immutable referralRegistry;
    ITVLLeaderboard public immutable tvlLeaderboard;
    
    // Simplified user tracking
    mapping(PoolId => mapping(address => address)) public userReferrer;
    mapping(address => uint256) public kolTotalTVL;
    mapping(address => uint256) public kolUniqueUsers;
    mapping(address => mapping(address => bool)) private kolUserSeen;
    
    event ReferralTracked(address indexed user, address indexed kol, PoolId indexed poolId, uint256 tvl, bool isDeposit);
    event HookExecutionDebug(string step, address user, address kol, uint256 tokenId, uint256 tvl);
    event HookError(string step, address user, string reason);
    
    constructor(
        IPoolManager _manager,
        IReferralRegistry _referralRegistry,
        ITVLLeaderboard _tvlLeaderboard
    ) BaseHook(_manager) {
        referralRegistry = _referralRegistry;
        tvlLeaderboard = _tvlLeaderboard;
    }
    
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: true,
            beforeSwap: false,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
    
    function setReferral(string memory referralCode) external {
        referralRegistry.setUserReferral(msg.sender, referralCode);
    }
    
    function _afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        emit HookExecutionDebug("afterAddLiquidity_start", sender, address(0), 0, 0);
        
        if (params.liquidityDelta <= 0) {
            emit HookExecutionDebug("early_return_liquidityDelta", sender, address(0), 0, uint256(params.liquidityDelta));
            return (this.afterAddLiquidity.selector, BalanceDelta.wrap(0));
        }
        
        PoolId poolId = key.toId();
        (uint256 tokenId, address kol,) = referralRegistry.getUserReferralInfo(sender);
        
        emit HookExecutionDebug("got_user_info", sender, kol, tokenId, 0);
        
        if (kol != address(0) && tokenId != 0) {
            userReferrer[poolId][sender] = kol;
            
            // Track unique user
            if (!kolUserSeen[kol][sender]) {
                kolUserSeen[kol][sender] = true;
                require(kolUniqueUsers[kol] < type(uint256).max, "ReferralHook: KOL unique users overflow");
                kolUniqueUsers[kol]++;
            }
            
            // Simple TVL calculation
            uint256 tvl = _calculateTVL(delta);
            require(kolTotalTVL[kol] <= type(uint256).max - tvl, "ReferralHook: KOL TVL overflow on add");
            kolTotalTVL[kol] += tvl;
            
            emit HookExecutionDebug("calculated_tvl", sender, kol, tokenId, tvl);
            
            // Update registry with new total TVL - with error handling
            try referralRegistry.updateTVL(tokenId, kolTotalTVL[kol]) {
                emit HookExecutionDebug("registry_updated", sender, kol, tokenId, kolTotalTVL[kol]);
            } catch Error(string memory reason) {
                emit HookError("registry_update_failed", sender, reason);
            } catch {
                emit HookError("registry_update_failed", sender, "unknown_error");
            }
            
            // Update external contracts - with error handling
            try tvlLeaderboard.updateKOLMetrics(kol, tvl, true, kolUniqueUsers[kol]) {
                emit HookExecutionDebug("leaderboard_updated", sender, kol, tokenId, tvl);
            } catch Error(string memory reason) {
                emit HookError("leaderboard_update_failed", sender, reason);
            } catch {
                emit HookError("leaderboard_update_failed", sender, "unknown_error");
            }
            
            emit ReferralTracked(sender, kol, poolId, tvl, true);
        } else {
            emit HookExecutionDebug("conditions_not_met", sender, kol, tokenId, 0);
        }
        
        return (this.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }
    
    function _afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        if (params.liquidityDelta >= 0) return (this.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
        
        PoolId poolId = key.toId();
        address kol = userReferrer[poolId][sender];
        
        if (kol != address(0)) {
            // Get the token ID for the KOL to update registry
            (uint256 tokenId, ,) = referralRegistry.getUserReferralInfo(sender);
            
            uint256 tvl = _calculateTVL(delta);
            require(kolTotalTVL[kol] >= tvl, "ReferralHook: KOL TVL underflow on removal");
            kolTotalTVL[kol] -= tvl;
            
            // Update registry with new total TVL
            if (tokenId != 0) {
                referralRegistry.updateTVL(tokenId, kolTotalTVL[kol]);
            }
            
            tvlLeaderboard.updateKOLMetrics(kol, tvl, false, kolUniqueUsers[kol]);
            emit ReferralTracked(sender, kol, poolId, tvl, false);
        }
        
        return (this.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }
    
    function _calculateTVL(BalanceDelta delta) private pure returns (uint256) {
        int256 amount0 = delta.amount0();
        int256 amount1 = delta.amount1();
        
        uint256 tvl = 0;
        if (amount0 > 0) tvl += uint256(amount0);
        else if (amount0 < 0) tvl += uint256(-amount0);
        
        if (amount1 > 0) tvl += uint256(amount1);
        else if (amount1 < 0) tvl += uint256(-amount1);
        
        return tvl;
    }
    
    // View functions
    function getKOLStats(address kol) external view returns (uint256 totalTVL, uint256 uniqueUsers) {
        return (kolTotalTVL[kol], kolUniqueUsers[kol]);
    }
    
    function getUserReferrer(PoolId poolId, address user) external view returns (address) {
        return userReferrer[poolId][user];
    }
} 