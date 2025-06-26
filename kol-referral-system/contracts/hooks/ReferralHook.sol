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
    
    // Known PositionManager addresses
    mapping(address => bool) public isPositionManager;
    
    // Simplified user tracking
    mapping(PoolId => mapping(address => address)) public userReferrer;
    mapping(address => uint256) public kolTotalTVL;
    mapping(address => uint256) public kolUniqueUsers;
    mapping(address => mapping(address => bool)) private kolUserSeen;
    
    event ReferralTracked(address indexed user, address indexed kol, PoolId indexed poolId, uint256 tvl, bool isDeposit);
    event HookExecutionDebug(string step, address user, address kol, uint256 tokenId, uint256 tvl);
    event HookError(string step, address user, string reason);
    event UserResolution(address sender, address resolvedUser, string method);
    
    constructor(
        IPoolManager _manager,
        IReferralRegistry _referralRegistry,
        ITVLLeaderboard _tvlLeaderboard
    ) BaseHook(_manager) {
        referralRegistry = _referralRegistry;
        tvlLeaderboard = _tvlLeaderboard;
        
        // Add known PositionManager addresses
        isPositionManager[0x7C5f5A4bBd8fD63184577525326123B519429bDc] = true; // Base Mainnet PositionManager
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
    
    // Admin function to add/remove PositionManager addresses
    function setPositionManager(address positionManager, bool isManager) external {
        // Simple access control - in production you'd want proper roles
        require(msg.sender == tx.origin, "Only EOA can set position managers");
        isPositionManager[positionManager] = isManager;
    }
    
    /**
     * @dev Resolves the actual user address from the transaction context
     * @param sender The immediate sender (could be PositionManager)
     * @param hookData Optional data that might contain the real user address
     * @return actualUser The resolved user address
     */
    function _resolveActualUser(address sender, bytes calldata hookData) internal returns (address actualUser) {
        // Method 1: Check if hookData contains user address (32 bytes)
        if (hookData.length >= 32) {
            address hookDataUser = abi.decode(hookData, (address));
            if (hookDataUser != address(0)) {
                emit UserResolution(sender, hookDataUser, "hookData");
                return hookDataUser;
            }
        }
        
        // Method 2: If sender is a known PositionManager, use tx.origin
        if (isPositionManager[sender]) {
            emit UserResolution(sender, tx.origin, "tx.origin");
            return tx.origin;
        }
        
        // Method 3: Default to sender
        emit UserResolution(sender, sender, "direct");
        return sender;
    }
    
    function _afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata hookData
    ) internal override returns (bytes4, BalanceDelta) {
        emit HookExecutionDebug("afterAddLiquidity_start", sender, address(0), 0, 0);
        
        if (params.liquidityDelta <= 0) {
            emit HookExecutionDebug("early_return_liquidityDelta", sender, address(0), 0, uint256(params.liquidityDelta));
            return (this.afterAddLiquidity.selector, BalanceDelta.wrap(0));
        }
        
        // Resolve the actual user
        address actualUser = _resolveActualUser(sender, hookData);
        emit HookExecutionDebug("resolved_user", actualUser, address(0), 0, 0);
        
        PoolId poolId = key.toId();
        (uint256 tokenId, address kol,) = referralRegistry.getUserReferralInfo(actualUser);
        
        emit HookExecutionDebug("got_user_info", actualUser, kol, tokenId, 0);
        
        if (kol != address(0) && tokenId != 0) {
            // Use actualUser instead of sender for tracking
            userReferrer[poolId][actualUser] = kol;
            
            // Track unique user
            if (!kolUserSeen[kol][actualUser]) {
                kolUserSeen[kol][actualUser] = true;
                require(kolUniqueUsers[kol] < type(uint256).max, "ReferralHook: KOL unique users overflow");
                kolUniqueUsers[kol]++;
            }
            
            // Simple TVL calculation
            uint256 tvl = _calculateTVL(delta);
            require(kolTotalTVL[kol] <= type(uint256).max - tvl, "ReferralHook: KOL TVL overflow on add");
            kolTotalTVL[kol] += tvl;
            
            emit HookExecutionDebug("calculated_tvl", actualUser, kol, tokenId, tvl);
            
            // Update registry with new total TVL - with error handling
            try referralRegistry.updateTVL(tokenId, kolTotalTVL[kol]) {
                emit HookExecutionDebug("registry_updated", actualUser, kol, tokenId, kolTotalTVL[kol]);
            } catch Error(string memory reason) {
                emit HookError("registry_update_failed", actualUser, reason);
            } catch {
                emit HookError("registry_update_failed", actualUser, "unknown_error");
            }
            
            // Update external contracts - with error handling
            try tvlLeaderboard.updateKOLMetrics(kol, tvl, true, kolUniqueUsers[kol]) {
                emit HookExecutionDebug("leaderboard_updated", actualUser, kol, tokenId, tvl);
            } catch Error(string memory reason) {
                emit HookError("leaderboard_update_failed", actualUser, reason);
            } catch {
                emit HookError("leaderboard_update_failed", actualUser, "unknown_error");
            }
            
            emit ReferralTracked(actualUser, kol, poolId, tvl, true);
        } else {
            emit HookExecutionDebug("conditions_not_met", actualUser, kol, tokenId, 0);
        }
        
        return (this.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }
    
    function _afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata hookData
    ) internal override returns (bytes4, BalanceDelta) {
        if (params.liquidityDelta >= 0) return (this.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
        
        // Resolve the actual user
        address actualUser = _resolveActualUser(sender, hookData);
        
        PoolId poolId = key.toId();
        address kol = userReferrer[poolId][actualUser];
        
        if (kol != address(0)) {
            // Get the token ID for the KOL to update registry
            (uint256 tokenId, ,) = referralRegistry.getUserReferralInfo(actualUser);
            
            uint256 tvl = _calculateTVL(delta);
            require(kolTotalTVL[kol] >= tvl, "ReferralHook: KOL TVL underflow on removal");
            kolTotalTVL[kol] -= tvl;
            
            // Update registry with new total TVL
            if (tokenId != 0) {
                referralRegistry.updateTVL(tokenId, kolTotalTVL[kol]);
            }
            
            tvlLeaderboard.updateKOLMetrics(kol, tvl, false, kolUniqueUsers[kol]);
            emit ReferralTracked(actualUser, kol, poolId, tvl, false);
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