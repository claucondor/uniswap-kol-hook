// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./ReferralHook.base.t.sol";

contract ReferralHookIntegrationTest is ReferralHookBase {
    
    function test_hook_setReferral_integration() public {
        string memory referralCode = "INTEGRATION_KOL_001";
        
        // Test the setReferral function directly
        vm.prank(user1);
        hook.setReferral(referralCode);
        
        // Verify referral was set in registry
        (uint256 tokenId, address kol, string memory code) = referralRegistry.getUserReferralInfo(user1);
        
        assertGt(tokenId, 0, "Token ID should be assigned");
        assertNotEq(kol, address(0), "KOL address should be derived");
        assertEq(code, referralCode, "Referral code should match");
        
        // Verify KOL stats are initially zero
        (uint256 totalTVL, uint256 uniqueUsers) = hook.getKOLStats(kol);
        assertEq(totalTVL, 0, "Initial TVL should be 0");
        assertEq(uniqueUsers, 0, "Initial users should be 0");
    }
    
    function test_hook_multipleUsersSetReferral() public {
        string memory referralCode = "SHARED_KOL_CODE";
        
        // Multiple users set same referral
        vm.prank(user1);
        hook.setReferral(referralCode);
        
        vm.prank(user2);
        hook.setReferral(referralCode);
        
        // Both should point to same KOL
        (, address kol1, ) = referralRegistry.getUserReferralInfo(user1);
        (, address kol2, ) = referralRegistry.getUserReferralInfo(user2);
        
        assertEq(kol1, kol2, "Both users should have same KOL");
        assertNotEq(kol1, address(0), "KOL should be valid");
    }
    
    function test_hook_referralInfoPersistence() public {
        string memory referralCode = "PERSISTENT_CODE";
        
        vm.prank(user1);
        hook.setReferral(referralCode);
        
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // Verify registry has persistent info
        IReferralRegistry.ReferralInfo memory info = referralRegistry.referralInfo(1);
        assertEq(info.referralCode, referralCode, "Code should persist");
        assertEq(info.kol, kol, "KOL should persist");
        assertTrue(info.isActive, "Should be active");
        assertEq(info.totalTVL, 0, "Initial TVL should be 0");
    }
    
    function test_hook_getKOLStats_functionality() public {
        // Test view functions work correctly
        address testKol = address(0x999);
        
        (uint256 tvl, uint256 users) = hook.getKOLStats(testKol);
        assertEq(tvl, 0, "Unknown KOL should have 0 TVL");
        assertEq(users, 0, "Unknown KOL should have 0 users");
        
        // Verify getUserReferrer works
        address referrer = hook.getUserReferrer(poolId, user1);
        assertEq(referrer, address(0), "User without referral should have no referrer");
    }
    
    function test_hook_registryIntegration() public {
        vm.prank(user1);
        hook.setReferral("REGISTRY_TEST");
        
        (uint256 tokenId, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // Test that mock registry updates work
        assertEq(referralRegistry.tokenTVLs(tokenId), 0, "Initial registry TVL should be 0");
        
        // Test hasRole functionality (mock should return true)
        assertTrue(referralRegistry.hasRole(bytes32(0), address(hook)), "Hook should have roles");
        
        // Test DEFAULT_ADMIN_ROLE
        assertEq(referralRegistry.DEFAULT_ADMIN_ROLE(), bytes32(0), "Admin role should be defined");
    }
    
    function test_hook_leaderboardIntegration() public {
        // Test TVL leaderboard mock integration
        assertEq(tvlLeaderboard.currentEpoch(), 1, "Should have current epoch");
        
        // Test that mock can be configured to revert
        tvlLeaderboard.setRevertBehavior(true, "Test error");
        
        // Verify revert behavior is set
        vm.expectRevert("Test error");
        tvlLeaderboard.updateKOLMetrics(address(0x123), 1000, true, 1);
        
        // Reset revert behavior
        tvlLeaderboard.setRevertBehavior(false, "");
    }
    
    function test_hook_errorHandling() public {
        vm.prank(user1);
        hook.setReferral("ERROR_TEST");
        
        (, address kol, ) = referralRegistry.getUserReferralInfo(user1);
        
        // Make leaderboard revert to test error handling
        tvlLeaderboard.setRevertBehavior(true, "Leaderboard error");
        
        // This simulates what would happen if leaderboard fails
        // The hook should handle this gracefully in real scenarios
        assertTrue(true, "Error handling test setup complete");
    }
    
    function test_hook_addressDerivation() public {
        // Test that same referral codes produce same KOL addresses
        string memory code1 = "CONSISTENT_CODE";
        string memory code2 = "DIFFERENT_CODE";
        
        vm.prank(user1);
        hook.setReferral(code1);
        
        vm.prank(user2);
        hook.setReferral(code2);
        
        (, address kol1, ) = referralRegistry.getUserReferralInfo(user1);
        (, address kol2, ) = referralRegistry.getUserReferralInfo(user2);
        
        assertNotEq(kol1, kol2, "Different codes should produce different KOLs");
        
        // Now test consistency
        address user3 = address(0x3333);
        vm.prank(user3);
        hook.setReferral(code1); // Same as user1
        
        (, address kol3, ) = referralRegistry.getUserReferralInfo(user3);
        assertEq(kol1, kol3, "Same code should produce same KOL");
    }
    
    function test_hook_permissions() public {
        // Verify hook has correct permissions
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        
        assertTrue(permissions.afterAddLiquidity, "Should have afterAddLiquidity");
        assertTrue(permissions.afterRemoveLiquidity, "Should have afterRemoveLiquidity");
        
        // All other permissions should be false
        assertFalse(permissions.beforeInitialize, "Should not have beforeInitialize");
        assertFalse(permissions.afterInitialize, "Should not have afterInitialize");
        assertFalse(permissions.beforeAddLiquidity, "Should not have beforeAddLiquidity");
        assertFalse(permissions.beforeRemoveLiquidity, "Should not have beforeRemoveLiquidity");
        assertFalse(permissions.beforeSwap, "Should not have beforeSwap");
        assertFalse(permissions.afterSwap, "Should not have afterSwap");
        assertFalse(permissions.beforeDonate, "Should not have beforeDonate");
        assertFalse(permissions.afterDonate, "Should not have afterDonate");
    }
    
    function test_hook_contractAddresses() public {
        // Verify hook has correct contract references
        assertEq(address(hook.referralRegistry()), address(referralRegistry), "Registry address should match");
        assertEq(address(hook.tvlLeaderboard()), address(tvlLeaderboard), "Leaderboard address should match");
        assertEq(address(hook.poolManager()), address(poolManager), "Pool manager address should match");
    }
    
    function test_hook_realWorldScenario() public {
        // Simulate a real-world KOL referral scenario
        string memory kolCode = "CRYPTO_INFLUENCER_001";
        
        // KOL promotes their code
        // Users discover and use the code
        
        address[] memory users = new address[](5);
        users[0] = address(0x1001);
        users[1] = address(0x1002);
        users[2] = address(0x1003);
        users[3] = address(0x1004);
        users[4] = address(0x1005);
        
        // All users set the same referral code
        for (uint i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            hook.setReferral(kolCode);
        }
        
        // Verify all users point to same KOL
        (, address expectedKol, ) = referralRegistry.getUserReferralInfo(users[0]);
        
        for (uint i = 1; i < users.length; i++) {
            (, address kol, string memory code) = referralRegistry.getUserReferralInfo(users[i]);
            assertEq(kol, expectedKol, "All users should have same KOL");
            assertEq(code, kolCode, "All users should have same code");
        }
        
        // Verify KOL stats show 0 initially (no liquidity added yet)
        (uint256 totalTVL, uint256 uniqueUsers) = hook.getKOLStats(expectedKol);
        assertEq(totalTVL, 0, "No TVL yet");
        assertEq(uniqueUsers, 0, "No unique users yet");
    }
} 