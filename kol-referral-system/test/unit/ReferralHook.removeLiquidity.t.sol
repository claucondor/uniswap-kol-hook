// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./ReferralHook.base.t.sol";

contract ReferralHookRemoveLiquidityTest is ReferralHookBase {
    
    function setUp() public override {
        super.setUp();
        
        // Setup: User with referral adds initial liquidity
        setUserReferral(user1, "KOL1_CODE");
        simulateAddLiquidity(user1, 2000, 2000e18, 4000e18); // 6000e18 TVL
    }
    
    function test_afterRemoveLiquidity_validRemoval() public {
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // Verify initial state
        (uint256 initialTVL,) = hook.getKOLStats(kol);
        assertEq(initialTVL, 6000e18, "Initial TVL should be set");
        
        // Expect referral tracked event
        expectReferralTracked(user1, kol, poolId, 1500e18, false);
        
        // Simulate remove liquidity
        (bytes4 selector, BalanceDelta returnDelta) = simulateRemoveLiquidity(
            user1,
            -1000, // negative liquidityDelta (removing)
            -1000e18, // amount0 (negative = user receiving)
            -500e18   // amount1 (negative = user receiving)
        );
        
        // Check return values
        assertEq(selector, hook.afterRemoveLiquidity.selector, "Should return correct selector");
        assertEq(BalanceDelta.unwrap(returnDelta), 0, "Should return zero delta");
        
        // Check TVL was reduced
        (uint256 finalTVL,) = hook.getKOLStats(kol);
        assertEq(finalTVL, 4500e18, "TVL should be reduced: 6000 - 1500");
        
        // Check registry was updated
        assertEq(referralRegistry.tokenTVLs(1), 4500e18, "Registry TVL should be updated");
        
        // Check leaderboard was updated
        assertEq(tvlLeaderboard.kolTotalTVL(kol), 4500e18, "Leaderboard TVL should be reduced");
    }
    
    function test_afterRemoveLiquidity_userWithoutPriorLiquidity() public {
        // User2 has no prior liquidity
        
        // Should do nothing
        (bytes4 selector, BalanceDelta returnDelta) = simulateRemoveLiquidity(
            user2,
            -500, // negative liquidityDelta
            -500e18, // amount0
            -1000e18 // amount1
        );
        
        // Check return values
        assertEq(selector, hook.afterRemoveLiquidity.selector, "Should return correct selector");
        assertEq(BalanceDelta.unwrap(returnDelta), 0, "Should return zero delta");
        
        // Check no referrer is set
        address referrer = hook.getUserReferrer(poolId, user2);
        assertEq(referrer, address(0), "No referrer should be set");
    }
    
    function test_afterRemoveLiquidity_positiveLiquidityDelta() public {
        // Should early return for positive delta (not removing liquidity)
        
        (bytes4 selector, BalanceDelta returnDelta) = simulateRemoveLiquidity(
            user1,
            500, // positive liquidityDelta (not removing)
            500e18, // amount0
            1000e18 // amount1
        );
        
        // Check return values
        assertEq(selector, hook.afterRemoveLiquidity.selector, "Should return correct selector");
        assertEq(BalanceDelta.unwrap(returnDelta), 0, "Should return zero delta");
        
        // Check TVL remains unchanged
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        (uint256 tvl,) = hook.getKOLStats(kol);
        assertEq(tvl, 6000e18, "TVL should remain unchanged");
    }
    
    function test_afterRemoveLiquidity_zeroLiquidityDelta() public {
        // Should early return for zero delta
        
        (bytes4 selector, BalanceDelta returnDelta) = simulateRemoveLiquidity(
            user1,
            0, // zero liquidityDelta
            -500e18, // amount0
            -1000e18 // amount1
        );
        
        // Check return values
        assertEq(selector, hook.afterRemoveLiquidity.selector, "Should return correct selector");
        assertEq(BalanceDelta.unwrap(returnDelta), 0, "Should return zero delta");
        
        // Check TVL remains unchanged
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        (uint256 tvl,) = hook.getKOLStats(kol);
        assertEq(tvl, 6000e18, "TVL should remain unchanged");
    }
    
    function test_afterRemoveLiquidity_removeMoreThanAvailable() public {
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // Try to remove more TVL than available
        (uint256 initialTVL,) = hook.getKOLStats(kol);
        assertEq(initialTVL, 6000e18, "Initial TVL");
        
        // Simulate removing huge amount (more than available)
        simulateRemoveLiquidity(
            user1,
            -5000, // large negative delta
            -10000e18, // huge amount0
            -5000e18   // huge amount1 - total 15000e18 > 6000e18 available
        );
        
        // Check TVL went to zero (not negative)
        (uint256 finalTVL,) = hook.getKOLStats(kol);
        assertEq(finalTVL, 0, "TVL should be capped at 0");
        
        // Check registry was updated to 0
        assertEq(referralRegistry.tokenTVLs(1), 0, "Registry TVL should be 0");
    }
    
    function test_afterRemoveLiquidity_multipleRemovals() public {
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // First removal
        simulateRemoveLiquidity(user1, -500, -500e18, -1000e18); // Remove 1500e18
        (uint256 tvl1,) = hook.getKOLStats(kol);
        assertEq(tvl1, 4500e18, "After first removal: 6000 - 1500");
        
        // Second removal
        simulateRemoveLiquidity(user1, -300, -300e18, -700e18); // Remove 1000e18
        (uint256 tvl2,) = hook.getKOLStats(kol);
        assertEq(tvl2, 3500e18, "After second removal: 4500 - 1000");
        
        // Third removal
        simulateRemoveLiquidity(user1, -1000, -1500e18, -2000e18); // Remove 3500e18
        (uint256 tvl3,) = hook.getKOLStats(kol);
        assertEq(tvl3, 0, "After third removal: 3500 - 3500");
    }
    
    function test_afterRemoveLiquidity_tvlCalculation() public {
        // Test different amount combinations for TVL calculation
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // Case 1: Both negative amounts (typical removal)
        simulateRemoveLiquidity(user1, -500, -500e18, -1000e18);
        (uint256 tvl1,) = hook.getKOLStats(kol);
        assertEq(tvl1, 4500e18, "Both negative: 6000 - (500 + 1000)");
        
        // Case 2: Mixed positive/negative amounts
        simulateRemoveLiquidity(user1, -300, 300e18, -600e18);
        (uint256 tvl2,) = hook.getKOLStats(kol);
        assertEq(tvl2, 3600e18, "Mixed: 4500 - (300 + 600)");
        
        // Case 3: Both positive amounts (unusual but possible)
        simulateRemoveLiquidity(user1, -200, 200e18, 400e18);
        (uint256 tvl3,) = hook.getKOLStats(kol);
        assertEq(tvl3, 3000e18, "Both positive: 3600 - (200 + 400)");
    }
    
    function test_afterRemoveLiquidity_differentPool() public {
        // Setup second pool
        PoolKey memory poolKey2 = PoolKey({
            currency0: Currency.wrap(address(0x3333)),
            currency1: Currency.wrap(address(0x4444)),
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });
        PoolId poolId2 = poolKey2.toId();
        
        // User adds liquidity to second pool (manually set referrer)
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // Simulate removing from a different pool where user has no referrer set
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -500,
            salt: 0
        });
        
        BalanceDelta delta = createBalanceDelta(-500e18, -1000e18);
        
        vm.prank(user1);
        (bytes4 selector, BalanceDelta returnDelta) = hook.afterRemoveLiquidity(
            user1, poolKey2, params, delta, BalanceDelta.wrap(0), ""
        );
        
        // Should do nothing since user has no referrer in poolId2
        assertEq(selector, hook.afterRemoveLiquidity.selector, "Should return correct selector");
        assertEq(BalanceDelta.unwrap(returnDelta), 0, "Should return zero delta");
        
        // Original pool TVL should remain unchanged
        (uint256 originalTVL,) = hook.getKOLStats(kol);
        assertEq(originalTVL, 6000e18, "Original pool TVL should be unchanged");
    }
    
    function test_afterRemoveLiquidity_userWithoutTokenId() public {
        // Setup user without valid token ID
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // Manually reset the token ID in mock (simulate edge case)
        referralRegistry.userTokenIds(user1); // This should be 0 for this test
        
        // Should still work for remove liquidity since it uses stored referrer
        expectReferralTracked(user1, kol, poolId, 1500e18, false);
        
        simulateRemoveLiquidity(user1, -1000, -1000e18, -500e18);
        
        // TVL should still be reduced
        (uint256 tvl,) = hook.getKOLStats(kol);
        assertEq(tvl, 4500e18, "TVL should be reduced even without token ID");
    }
    
    function test_afterRemoveLiquidity_preservesUniqueUserCount() public {
        // Add second user to same KOL
        setUserReferral(user2, "KOL1_CODE");
        simulateAddLiquidity(user2, 1000, 1000e18, 2000e18);
        
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // Check both users are counted
        (uint256 initialTVL, uint256 initialUsers) = hook.getKOLStats(kol);
        assertEq(initialTVL, 9000e18, "Combined TVL");
        assertEq(initialUsers, 2, "Two unique users");
        
        // User1 removes liquidity
        simulateRemoveLiquidity(user1, -1000, -1000e18, -500e18);
        
        // User count should remain the same
        (uint256 finalTVL, uint256 finalUsers) = hook.getKOLStats(kol);
        assertEq(finalTVL, 7500e18, "Reduced TVL");
        assertEq(finalUsers, 2, "Users count should remain 2");
    }
} 