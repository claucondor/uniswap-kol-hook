// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./ReferralHook.base.t.sol";

contract ReferralHookDeploymentTest is ReferralHookBase {
    
    function test_deployment_initialState() public {
        // Check that contracts are correctly set
        assertEq(address(hook.referralRegistry()), address(referralRegistry), "ReferralRegistry should be set");
        assertEq(address(hook.tvlLeaderboard()), address(tvlLeaderboard), "TVLLeaderboard should be set");
        assertEq(address(hook.poolManager()), address(poolManager), "PoolManager should be set");
    }
    
    function test_deployment_hookPermissions() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        
        // Check that only afterAddLiquidity and afterRemoveLiquidity are enabled
        assertFalse(permissions.beforeInitialize, "beforeInitialize should be false");
        assertFalse(permissions.afterInitialize, "afterInitialize should be false");
        assertFalse(permissions.beforeAddLiquidity, "beforeAddLiquidity should be false");
        assertTrue(permissions.afterAddLiquidity, "afterAddLiquidity should be true");
        assertFalse(permissions.beforeRemoveLiquidity, "beforeRemoveLiquidity should be false");
        assertTrue(permissions.afterRemoveLiquidity, "afterRemoveLiquidity should be true");
        assertFalse(permissions.beforeSwap, "beforeSwap should be false");
        assertFalse(permissions.afterSwap, "afterSwap should be false");
        assertFalse(permissions.beforeDonate, "beforeDonate should be false");
        assertFalse(permissions.afterDonate, "afterDonate should be false");
        assertFalse(permissions.beforeSwapReturnDelta, "beforeSwapReturnDelta should be false");
        assertFalse(permissions.afterSwapReturnDelta, "afterSwapReturnDelta should be false");
        assertFalse(permissions.afterAddLiquidityReturnDelta, "afterAddLiquidityReturnDelta should be false");
        assertFalse(permissions.afterRemoveLiquidityReturnDelta, "afterRemoveLiquidityReturnDelta should be false");
    }
    
    function test_setReferral_functionality() public {
        string memory referralCode = "TEST_KOL_001";
        
        // User sets referral
        setUserReferral(user1, referralCode);
        
        // Check that referral was set in the registry
        (uint256 tokenId, address referredBy, string memory code) = referralRegistry.getUserReferralInfo(user1);
        
        assertGt(tokenId, 0, "Token ID should be set");
        assertNotEq(referredBy, address(0), "ReferredBy should be set");
        assertEq(code, referralCode, "Referral code should match");
    }
    
    function test_getKOLStats_initialState() public {
        (uint256 totalTVL, uint256 uniqueUsers) = hook.getKOLStats(kol1);
        
        assertEq(totalTVL, 0, "Initial TVL should be 0");
        assertEq(uniqueUsers, 0, "Initial unique users should be 0");
    }
    
    function test_getUserReferrer_initialState() public {
        address referrer = hook.getUserReferrer(poolId, user1);
        assertEq(referrer, address(0), "Initial referrer should be zero address");
    }
} 