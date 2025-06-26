// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TVLLeaderboard.base.t.sol";

contract TVLLeaderboardMetricsTest is TVLLeaderboardBase {
    
    function test_updateMetrics_firstDeposit() public {
        uint256 depositAmount = 1000e18;
        uint256 userCount = 1;
        
        vm.expectEmit(true, true, false, true);
        emit TVLLeaderboard.KOLAdded(kol1, 1);
        
        vm.expectEmit(true, true, false, true);
        emit TVLLeaderboard.MetricsUpdated(kol1, 1, depositAmount, true, depositAmount);
        
        updateMetricsAsHook(kol1, depositAmount, true, userCount);
        
        // Check KOL was added to active list
        address[] memory activeKOLs = leaderboard.getActiveKOLs();
        assertEq(activeKOLs.length, 1, "Should have 1 active KOL");
        assertEq(activeKOLs[0], kol1, "KOL1 should be in active list");
        
        // Check metrics
        KOLMetrics memory metrics = getCurrentMetrics(kol1);
        assertEq(metrics.totalTVL, depositAmount, "Total TVL should equal deposit");
        assertEq(metrics.deposits, depositAmount, "Deposits should equal deposit amount");
        assertEq(metrics.withdrawals, 0, "Withdrawals should be 0");
        assertEq(metrics.peakTVL, depositAmount, "Peak TVL should equal deposit");
        assertEq(metrics.uniqueUsers, userCount, "Unique users should be 1");
        assertEq(metrics.lastUpdateTime, block.timestamp, "Last update time should be current timestamp");
    }
    
    function test_updateMetrics_multipleDeposits() public {
        uint256 firstDeposit = 1000e18;
        uint256 secondDeposit = 2000e18;
        uint256 expectedTotal = firstDeposit + secondDeposit;
        
        // First deposit
        updateMetricsAsHook(kol1, firstDeposit, true, 1);
        
        // Second deposit with more users
        updateMetricsAsHook(kol1, secondDeposit, true, 3);
        
        // Check updated metrics
        KOLMetrics memory metrics = getCurrentMetrics(kol1);
        assertEq(metrics.totalTVL, expectedTotal, "Total TVL should be sum of deposits");
        assertEq(metrics.deposits, expectedTotal, "Total deposits should be sum");
        assertEq(metrics.peakTVL, expectedTotal, "Peak TVL should be updated");
        assertEq(metrics.uniqueUsers, 3, "Unique users should be updated to max");
        
        // Check sticky TVL
        uint256 stickyTVL = leaderboard.getStickyTVL(kol1);
        assertEq(stickyTVL, expectedTotal, "Sticky TVL should equal net deposits");
    }
    
    function test_updateMetrics_withdrawal() public {
        uint256 depositAmount = 2000e18;
        uint256 withdrawAmount = 500e18;
        uint256 expectedRemaining = depositAmount - withdrawAmount;
        
        // First make a deposit
        updateMetricsAsHook(kol1, depositAmount, true, 2);
        
        // Then withdraw some
        updateMetricsAsHook(kol1, withdrawAmount, false, 2);
        
        // Check metrics
        KOLMetrics memory metrics = getCurrentMetrics(kol1);
        assertEq(metrics.totalTVL, expectedRemaining, "Total TVL should be reduced");
        assertEq(metrics.deposits, depositAmount, "Deposits should remain unchanged");
        assertEq(metrics.withdrawals, withdrawAmount, "Withdrawals should be recorded");
        assertEq(metrics.peakTVL, depositAmount, "Peak TVL should remain at max");
        
        // Check sticky TVL
        uint256 stickyTVL = leaderboard.getStickyTVL(kol1);
        assertEq(stickyTVL, expectedRemaining, "Sticky TVL should reflect net amount");
    }
    
    function test_updateMetrics_withdrawalExceedsTVL() public {
        uint256 depositAmount = 1000e18;
        uint256 withdrawAmount = 1500e18; // More than deposited
        
        // First make a deposit
        updateMetricsAsHook(kol1, depositAmount, true, 1);
        
        // Then withdraw more than available
        updateMetricsAsHook(kol1, withdrawAmount, false, 1);
        
        // Check metrics - TVL should not go negative
        KOLMetrics memory metrics = getCurrentMetrics(kol1);
        assertEq(metrics.totalTVL, 0, "Total TVL should be 0, not negative");
        assertEq(metrics.withdrawals, withdrawAmount, "Withdrawals should still be recorded");
        
        // Check sticky TVL - should be 0 since withdrawals > deposits
        uint256 stickyTVL = leaderboard.getStickyTVL(kol1);
        assertEq(stickyTVL, 0, "Sticky TVL should be 0 when withdrawals exceed deposits");
    }
    
    function test_updateMetrics_userCountCanOnlyIncrease() public {
        updateMetricsAsHook(kol1, 1000e18, true, 5);
        
        KOLMetrics memory metrics1 = getCurrentMetrics(kol1);
        assertEq(metrics1.uniqueUsers, 5, "Should start with 5 users");
        
        // Try to update with lower user count
        updateMetricsAsHook(kol1, 500e18, true, 3);
        
        KOLMetrics memory metrics2 = getCurrentMetrics(kol1);
        assertEq(metrics2.uniqueUsers, 5, "User count should not decrease");
    }
    
    function test_updateMetrics_onlyHookRole() public {
        expectAccessControlError(unauthorized, leaderboard.HOOK_ROLE());
        
        vm.prank(unauthorized);
        leaderboard.updateKOLMetrics(kol1, 1000e18, true, 1);
    }
    
    function test_updateMetrics_invalidKOLAddress() public {
        expectRevertWithMessage("Invalid KOL address");
        
        updateMetricsAsHook(address(0), 1000e18, true, 1);
    }
    
    function test_updateMetrics_whenPaused() public {
        // Pause the contract
        vm.prank(admin);
        leaderboard.pause();
        
        expectPausedError();
        updateMetricsAsHook(kol1, 1000e18, true, 1);
    }
    
    function test_forceUpdateMetrics_adminOnly() public {
        uint256 amount = 2000e18;
        
        // Should work as admin
        forceUpdateAsAdmin(kol1, amount, true, 2);
        
        KOLMetrics memory metrics = getCurrentMetrics(kol1);
        assertEq(metrics.totalTVL, amount, "Force update should work");
        
        // Should fail as unauthorized user
        expectAccessControlError(unauthorized, leaderboard.DEFAULT_ADMIN_ROLE());
        
        vm.prank(unauthorized);
        leaderboard.forceUpdateMetrics(kol2, amount, true, 1);
    }
    
    function test_updateMetrics_multipleKOLs() public {
        uint256 amount1 = 1000e18;
        uint256 amount2 = 2000e18;
        uint256 amount3 = 500e18;
        
        // Update different KOLs
        updateMetricsAsHook(kol1, amount1, true, 1);
        updateMetricsAsHook(kol2, amount2, true, 2);
        updateMetricsAsHook(kol3, amount3, true, 1);
        
        // Check all are active
        address[] memory activeKOLs = leaderboard.getActiveKOLs();
        assertEq(activeKOLs.length, 3, "Should have 3 active KOLs");
        
        // Check individual metrics
        assertEq(getCurrentMetrics(kol1).totalTVL, amount1, "KOL1 TVL correct");
        assertEq(getCurrentMetrics(kol2).totalTVL, amount2, "KOL2 TVL correct");
        assertEq(getCurrentMetrics(kol3).totalTVL, amount3, "KOL3 TVL correct");
    }
} 