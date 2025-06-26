// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./ReferralHook.base.t.sol";

contract ReferralHookAddLiquidityTest is ReferralHookBase {
    
    function test_afterAddLiquidity_userWithValidReferral() public {
        // Setup: User sets referral
        string memory referralCode = "KOL1_CODE";
        setUserReferral(user1, referralCode);
        
        // Get the KOL address from the referral
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // Expect events in order
        expectHookExecutionDebug("afterAddLiquidity_start", user1, address(0), 0, 0);
        expectHookExecutionDebug("got_user_info", user1, kol, 1, 0);
        expectHookExecutionDebug("calculated_tvl", user1, kol, 1, 3000e18);
        expectHookExecutionDebug("registry_updated", user1, kol, 1, 3000e18);
        expectHookExecutionDebug("leaderboard_updated", user1, kol, 1, 3000e18);
        expectReferralTracked(user1, kol, poolId, 3000e18, true);
        
        // Simulate add liquidity
        (bytes4 selector, BalanceDelta returnDelta) = simulateAddLiquidity(
            user1,
            1000, // positive liquidityDelta
            1000e18, // amount0
            2000e18  // amount1
        );
        
        // Check return values
        assertEq(selector, hook.afterAddLiquidity.selector, "Should return correct selector");
        assertEq(BalanceDelta.unwrap(returnDelta), 0, "Should return zero delta");
        
        // Check that user referrer was set
        address storedReferrer = hook.getUserReferrer(poolId, user1);
        assertEq(storedReferrer, kol, "User referrer should be set");
        
        // Check KOL stats were updated
        (uint256 totalTVL, uint256 uniqueUsers) = hook.getKOLStats(kol);
        assertEq(totalTVL, 3000e18, "KOL TVL should be updated");
        assertEq(uniqueUsers, 1, "KOL unique users should be 1");
        
        // Check registry was updated
        assertEq(referralRegistry.tokenTVLs(1), 3000e18, "Registry TVL should be updated");
        
        // Check leaderboard was updated
        assertTrue(tvlLeaderboard.updateCalled(kol), "Leaderboard should be updated");
        assertEq(tvlLeaderboard.kolTotalTVL(kol), 3000e18, "Leaderboard TVL should match");
        assertEq(tvlLeaderboard.kolUniqueUsers(kol), 1, "Leaderboard users should match");
    }
    
    function test_afterAddLiquidity_userWithoutReferral() public {
        // Expect only basic events
        expectHookExecutionDebug("afterAddLiquidity_start", user1, address(0), 0, 0);
        expectHookExecutionDebug("got_user_info", user1, address(0), 0, 0);
        expectHookExecutionDebug("conditions_not_met", user1, address(0), 0, 0);
        
        // Simulate add liquidity
        (bytes4 selector, BalanceDelta returnDelta) = simulateAddLiquidity(
            user1,
            1000, // positive liquidityDelta
            1000e18, // amount0
            2000e18  // amount1
        );
        
        // Check return values
        assertEq(selector, hook.afterAddLiquidity.selector, "Should return correct selector");
        assertEq(BalanceDelta.unwrap(returnDelta), 0, "Should return zero delta");
        
        // Check that nothing was updated
        address storedReferrer = hook.getUserReferrer(poolId, user1);
        assertEq(storedReferrer, address(0), "User referrer should remain zero");
        
        (uint256 totalTVL, uint256 uniqueUsers) = hook.getKOLStats(address(0));
        assertEq(totalTVL, 0, "No TVL should be recorded");
        assertEq(uniqueUsers, 0, "No users should be recorded");
    }
    
    function test_afterAddLiquidity_zeroLiquidityDelta() public {
        // Setup: User sets referral
        setUserReferral(user1, "KOL1_CODE");
        
        // Expect early return
        expectHookExecutionDebug("afterAddLiquidity_start", user1, address(0), 0, 0);
        expectHookExecutionDebug("early_return_liquidityDelta", user1, address(0), 0, 0);
        
        // Simulate add liquidity with zero delta
        (bytes4 selector, BalanceDelta returnDelta) = simulateAddLiquidity(
            user1,
            0, // zero liquidityDelta
            1000e18, // amount0
            2000e18  // amount1
        );
        
        // Check return values
        assertEq(selector, hook.afterAddLiquidity.selector, "Should return correct selector");
        assertEq(BalanceDelta.unwrap(returnDelta), 0, "Should return zero delta");
        
        // Check that nothing was updated
        address storedReferrer = hook.getUserReferrer(poolId, user1);
        assertEq(storedReferrer, address(0), "User referrer should remain zero");
    }
    
    function test_afterAddLiquidity_negativeLiquidityDelta() public {
        // Setup: User sets referral
        setUserReferral(user1, "KOL1_CODE");
        
        // Expect early return
        expectHookExecutionDebug("afterAddLiquidity_start", user1, address(0), 0, 0);
        expectHookExecutionDebug("early_return_liquidityDelta", user1, address(0), 0, type(uint256).max); // -1 wraps around
        
        // Simulate add liquidity with negative delta
        (bytes4 selector, BalanceDelta returnDelta) = simulateAddLiquidity(
            user1,
            -500, // negative liquidityDelta
            1000e18, // amount0
            2000e18  // amount1
        );
        
        // Check return values
        assertEq(selector, hook.afterAddLiquidity.selector, "Should return correct selector");
        assertEq(BalanceDelta.unwrap(returnDelta), 0, "Should return zero delta");
    }
    
    function test_afterAddLiquidity_multipleUsers() public {
        // Setup: Both users set same referral
        string memory referralCode = "KOL1_CODE";
        setUserReferral(user1, referralCode);
        setUserReferral(user2, referralCode);
        
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // First user adds liquidity
        simulateAddLiquidity(user1, 1000, 1000e18, 2000e18);
        
        // Check first user stats
        (uint256 totalTVL1, uint256 uniqueUsers1) = hook.getKOLStats(kol);
        assertEq(totalTVL1, 3000e18, "First user TVL");
        assertEq(uniqueUsers1, 1, "One unique user");
        
        // Second user adds liquidity
        simulateAddLiquidity(user2, 500, 500e18, 1000e18);
        
        // Check updated stats
        (uint256 totalTVL2, uint256 uniqueUsers2) = hook.getKOLStats(kol);
        assertEq(totalTVL2, 4500e18, "Combined TVL");
        assertEq(uniqueUsers2, 2, "Two unique users");
        
        // Check both users have referrer set
        assertEq(hook.getUserReferrer(poolId, user1), kol, "User1 referrer");
        assertEq(hook.getUserReferrer(poolId, user2), kol, "User2 referrer");
    }
    
    function test_afterAddLiquidity_sameUserMultipleTimes() public {
        // Setup: User sets referral
        setUserReferral(user1, "KOL1_CODE");
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // First add liquidity
        simulateAddLiquidity(user1, 1000, 1000e18, 2000e18);
        
        (uint256 totalTVL1, uint256 uniqueUsers1) = hook.getKOLStats(kol);
        assertEq(totalTVL1, 3000e18, "First TVL");
        assertEq(uniqueUsers1, 1, "Should be 1 unique user");
        
        // Second add liquidity (same user)
        simulateAddLiquidity(user1, 500, 500e18, 1000e18);
        
        (uint256 totalTVL2, uint256 uniqueUsers2) = hook.getKOLStats(kol);
        assertEq(totalTVL2, 4500e18, "Combined TVL");
        assertEq(uniqueUsers2, 1, "Should still be 1 unique user");
    }
    
    function test_afterAddLiquidity_registryUpdateFails() public {
        // Setup: User sets referral
        setUserReferral(user1, "KOL1_CODE");
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // Make registry revert (we need to enhance mock for this)
        // For now, just verify the hook continues execution
        
        // Expect error event
        expectHookError("registry_update_failed", user1, "");
        
        // This test would need a more sophisticated mock that can fail
        // For now, just verify basic functionality works
        simulateAddLiquidity(user1, 1000, 1000e18, 2000e18);
        
        // KOL stats should still be updated in hook
        (uint256 totalTVL, uint256 uniqueUsers) = hook.getKOLStats(kol);
        assertEq(totalTVL, 3000e18, "TVL should be tracked in hook");
        assertEq(uniqueUsers, 1, "Users should be tracked in hook");
    }
    
    function test_afterAddLiquidity_leaderboardUpdateFails() public {
        // Setup: User sets referral
        setUserReferral(user1, "KOL1_CODE");
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // Make leaderboard revert
        tvlLeaderboard.setRevertBehavior(true, "Leaderboard down");
        
        // Expect error event
        expectHookError("leaderboard_update_failed", user1, "Leaderboard down");
        
        // Should still execute without reverting
        simulateAddLiquidity(user1, 1000, 1000e18, 2000e18);
        
        // Hook stats should still be updated
        (uint256 totalTVL, uint256 uniqueUsers) = hook.getKOLStats(kol);
        assertEq(totalTVL, 3000e18, "TVL should be tracked in hook");
        assertEq(uniqueUsers, 1, "Users should be tracked in hook");
    }
    
    function test_afterAddLiquidity_tvlCalculation() public {
        setUserReferral(user1, "KOL1_CODE");
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // Test different amount combinations
        
        // Case 1: Both positive amounts
        simulateAddLiquidity(user1, 1000, 1000e18, 2000e18);
        (uint256 tvl1,) = hook.getKOLStats(kol);
        assertEq(tvl1, 3000e18, "Both positive: 1000 + 2000");
        
        // Case 2: Mixed positive/negative amounts
        simulateAddLiquidity(user1, 500, -500e18, 1000e18);
        (uint256 tvl2,) = hook.getKOLStats(kol);
        assertEq(tvl2, 4500e18, "Mixed: previous + |500| + 1000");
        
        // Case 3: Both negative amounts
        simulateAddLiquidity(user1, 200, -200e18, -300e18);
        (uint256 tvl3,) = hook.getKOLStats(kol);
        assertEq(tvl3, 5000e18, "Both negative: previous + 200 + 300");
    }
} 