// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TVLLeaderboard.base.t.sol";

contract TVLLeaderboardAdminTest is TVLLeaderboardBase {
    
    function test_pause_onlyAdmin() public {
        expectAccessControlError(unauthorized, leaderboard.DEFAULT_ADMIN_ROLE());
        
        vm.prank(unauthorized);
        leaderboard.pause();
    }
    
    function test_pause_success() public {
        assertFalse(leaderboard.paused(), "Should start unpaused");
        
        vm.prank(admin);
        leaderboard.pause();
        
        assertTrue(leaderboard.paused(), "Should be paused after pause()");
    }
    
    function test_unpause_onlyAdmin() public {
        // First pause the contract
        vm.prank(admin);
        leaderboard.pause();
        
        expectAccessControlError(unauthorized, leaderboard.DEFAULT_ADMIN_ROLE());
        
        vm.prank(unauthorized);
        leaderboard.unpause();
    }
    
    function test_unpause_success() public {
        // First pause
        vm.prank(admin);
        leaderboard.pause();
        assertTrue(leaderboard.paused(), "Should be paused");
        
        // Then unpause
        vm.prank(admin);
        leaderboard.unpause();
        assertFalse(leaderboard.paused(), "Should be unpaused after unpause()");
    }
    
    function test_pausedOperations_blocked() public {
        // Add some initial data
        updateMetricsAsHook(kol1, 1000e18, true, 1);
        
        // Pause the contract
        vm.prank(admin);
        leaderboard.pause();
        
        // Hook operations should be blocked
        expectPausedError();
        updateMetricsAsHook(kol1, 500e18, true, 1);
    }
    
    function test_pausedOperations_adminForceUpdateStillWorks() public {
        // Pause the contract
        vm.prank(admin);
        leaderboard.pause();
        
        // Admin force update should still work even when paused
        forceUpdateAsAdmin(kol1, 1000e18, true, 1);
        
        KOLMetrics memory metrics = getCurrentMetrics(kol1);
        assertEq(metrics.totalTVL, 1000e18, "Force update should work when paused");
    }
    
    function test_pausedOperations_viewFunctionsStillWork() public {
        // Add data first
        updateMetricsAsHook(kol1, 1000e18, true, 1);
        
        // Pause the contract
        vm.prank(admin);
        leaderboard.pause();
        
        // View functions should still work
        address[] memory activeKOLs = leaderboard.getActiveKOLs();
        assertEq(activeKOLs.length, 1, "View functions should work when paused");
        
        uint256 stickyTVL = leaderboard.getStickyTVL(kol1);
        assertEq(stickyTVL, 1000e18, "Sticky TVL view should work when paused");
        
        (uint256 currentEpoch, , , ) = leaderboard.getEpochInfo();
        assertEq(currentEpoch, 1, "Epoch info should work when paused");
    }
    
    function test_roleManagement_grantRoles() public {
        address newHook = address(0x200);
        address newSnapshot = address(0x201);
        
        vm.startPrank(admin);
        
        // Grant roles
        leaderboard.grantRole(leaderboard.HOOK_ROLE(), newHook);
        leaderboard.grantRole(leaderboard.SNAPSHOT_ROLE(), newSnapshot);
        
        vm.stopPrank();
        
        // Test new roles work
        vm.prank(newHook);
        leaderboard.updateKOLMetrics(kol1, 1000e18, true, 1);
        
        updateMetricsAsHook(kol1, 500e18, true, 1);
        advanceToNextEpoch();
        
        vm.prank(newSnapshot);
        leaderboard.finalizeEpoch();
        
        // Should succeed without reverts
    }
    
    function test_roleManagement_revokeRoles() public {
        vm.startPrank(admin);
        
        // Revoke hook role
        leaderboard.revokeRole(leaderboard.HOOK_ROLE(), hook);
        
        vm.stopPrank();
        
        // Original hook should no longer work
        expectAccessControlError(hook, leaderboard.HOOK_ROLE());
        
        vm.prank(hook);
        leaderboard.updateKOLMetrics(kol1, 1000e18, true, 1);
    }
    
    function test_emergencySetEpoch_functionality() public {
        // Add some data in current epoch
        updateMetricsAsHook(kol1, 1000e18, true, 1);
        
        (uint256 oldEpoch, , , ) = leaderboard.getEpochInfo();
        assertEq(oldEpoch, 1, "Should start in epoch 1");
        
        // Emergency set to new epoch
        uint256 newEpoch = 5;
        uint256 newStartTime = block.timestamp + 1000;
        
        vm.prank(admin);
        leaderboard.emergencySetEpoch(newEpoch, newStartTime);
        
        (uint256 currentEpoch, uint256 startTime, , ) = leaderboard.getEpochInfo();
        assertEq(currentEpoch, newEpoch, "Epoch should be updated");
        assertEq(startTime, newStartTime, "Start time should be updated");
        
        // Old epoch data should still be accessible
        (uint256 oldTotalTVL, , , , , , , , ) = leaderboard.epochMetrics(1, kol1);
        assertEq(oldTotalTVL, 1000e18, "Old epoch data should be preserved");
        
        // New epoch should start fresh
        (uint256 newTotalTVL, , , , , , , , ) = leaderboard.epochMetrics(newEpoch, kol1);
        assertEq(newTotalTVL, 0, "New epoch should start with zero metrics");
    }
    
    function test_forceUpdateMetrics_duplicatesNormalLogic() public {
        uint256 amount = 1500e18;
        uint256 userCount = 3;
        
        // Force update should behave exactly like normal update
        forceUpdateAsAdmin(kol1, amount, true, userCount);
        
        // Check it follows same logic
        address[] memory activeKOLs = leaderboard.getActiveKOLs();
        assertEq(activeKOLs.length, 1, "Should add KOL to active list");
        assertEq(activeKOLs[0], kol1, "Should be the correct KOL");
        
        KOLMetrics memory metrics = getCurrentMetrics(kol1);
        assertEq(metrics.totalTVL, amount, "Total TVL should be set");
        assertEq(metrics.deposits, amount, "Deposits should be set");
        assertEq(metrics.peakTVL, amount, "Peak TVL should be set");
        assertEq(metrics.uniqueUsers, userCount, "Users should be set");
        assertEq(metrics.lastUpdateTime, block.timestamp, "Update time should be current timestamp");
        
        uint256 stickyTVL = leaderboard.getStickyTVL(kol1);
        assertEq(stickyTVL, amount, "Sticky TVL should be set");
    }
    
    function test_largeScaleRanking_top100Limit() public {
        // Add more than 100 KOLs to test the top 100 limit
        for (uint i = 1; i <= 120; i++) {
            address testKOL = address(uint160(0x1000 + i));
            updateMetricsAsHook(testKOL, i * 1e18, true, 1); // Different TVL amounts
        }
        
        advanceToNextEpoch();
        finalizeEpochAsSnapshot();
        
        // Should only return top 100
        (address[] memory topKOLs, ) = leaderboard.getTopKOLs(1, 200); // Request more than 100
        assertEq(topKOLs.length, 100, "Should cap at top 100 KOLs");
        
        // Highest TVL should be first
        (uint256 firstTotalTVL, , , , , , , , ) = leaderboard.epochMetrics(1, topKOLs[0]);
        assertEq(firstTotalTVL, 120e18, "Highest TVL should be first");
        
        // 100th place should be 21st highest (120 down to 21)
        (uint256 lastTotalTVL, , , , , , , , ) = leaderboard.epochMetrics(1, topKOLs[99]);
        assertEq(lastTotalTVL, 21e18, "100th place should be 21st highest");
    }
    
    function test_getTopKOLs_variousLimits() public {
        // Add 5 KOLs
        for (uint i = 1; i <= 5; i++) {
            address testKOL = address(uint160(0x1000 + i));
            updateMetricsAsHook(testKOL, i * 1000e18, true, 1);
        }
        
        advanceToNextEpoch();
        finalizeEpochAsSnapshot();
        
        // Test different limits
        (address[] memory top3, ) = leaderboard.getTopKOLs(1, 3);
        assertEq(top3.length, 3, "Should return exactly 3");
        
        (address[] memory top10, ) = leaderboard.getTopKOLs(1, 10);
        assertEq(top10.length, 5, "Should return all 5 when limit exceeds available");
        
        (address[] memory top0, ) = leaderboard.getTopKOLs(1, 0);
        assertEq(top0.length, 0, "Should return empty array for 0 limit");
    }
    
    function test_epochInfo_timeCalculations() public {
        (uint256 currentEpoch, uint256 startTime, uint256 endTime, uint256 timeRemaining) = leaderboard.getEpochInfo();
        
        // Test time calculations are consistent
        assertEq(endTime, startTime + EPOCH_DURATION, "End time should be start + duration");
        assertEq(timeRemaining, endTime - block.timestamp, "Time remaining should be end - current");
        
        // Advance time and check again
        uint256 timeAdvance = 7 days;
        advanceTime(timeAdvance);
        
        (, , uint256 newEndTime, uint256 newTimeRemaining) = leaderboard.getEpochInfo();
        assertEq(newEndTime, endTime, "End time should not change");
        assertEq(newTimeRemaining, EPOCH_DURATION - timeAdvance, "Time remaining should decrease");
        
        // When epoch is over
        advanceTime(EPOCH_DURATION);
        (, , , uint256 finalTimeRemaining) = leaderboard.getEpochInfo();
        assertEq(finalTimeRemaining, 0, "Time remaining should be 0 when epoch is over");
    }
    
    function test_activeKOLs_persistence() public {
        // Add KOLs
        updateMetricsAsHook(kol1, 1000e18, true, 1);
        updateMetricsAsHook(kol2, 2000e18, true, 2);
        
        address[] memory activeKOLs1 = leaderboard.getActiveKOLs();
        assertEq(activeKOLs1.length, 2, "Should have 2 active KOLs");
        
        // Move to next epoch
        advanceToNextEpoch();
        finalizeEpochAsSnapshot();
        
        // Active KOLs should persist across epochs
        address[] memory activeKOLs2 = leaderboard.getActiveKOLs();
        assertEq(activeKOLs2.length, 2, "Active KOLs should persist across epochs");
        
        // Add new KOL in new epoch
        updateMetricsAsHook(kol3, 500e18, true, 1);
        
        address[] memory activeKOLs3 = leaderboard.getActiveKOLs();
        assertEq(activeKOLs3.length, 3, "Should now have 3 active KOLs");
    }
} 