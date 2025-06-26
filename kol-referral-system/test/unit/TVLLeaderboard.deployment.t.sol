// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TVLLeaderboard.base.t.sol";

contract TVLLeaderboardDeploymentTest is TVLLeaderboardBase {
    
    function test_deployment_initialState() public {
        // Check initial epoch configuration
        (uint256 currentEpoch, uint256 startTime, uint256 endTime, uint256 timeRemaining) = leaderboard.getEpochInfo();
        
        assertEq(currentEpoch, 1, "Should start at epoch 1");
        assertEq(startTime, block.timestamp, "Start time should be deployment time");
        assertEq(endTime, block.timestamp + EPOCH_DURATION, "End time should be start + duration");
        assertEq(timeRemaining, EPOCH_DURATION, "Time remaining should be full epoch duration");
        
        // Check constants
        assertEq(leaderboard.EPOCH_DURATION(), EPOCH_DURATION, "Epoch duration should be 30 days");
        
        // Check admin role
        assertTrue(leaderboard.hasRole(leaderboard.DEFAULT_ADMIN_ROLE(), admin), "Admin should have admin role");
        assertTrue(leaderboard.hasRole(leaderboard.SNAPSHOT_ROLE(), admin), "Admin should have snapshot role initially");
        
        // Check granted roles
        assertTrue(leaderboard.hasRole(leaderboard.HOOK_ROLE(), hook), "Hook should have hook role");
        assertTrue(leaderboard.hasRole(leaderboard.SNAPSHOT_ROLE(), snapshotManager), "Manager should have snapshot role");
        
        // Check initial active KOLs
        address[] memory activeKOLs = leaderboard.getActiveKOLs();
        assertEq(activeKOLs.length, 0, "Should start with no active KOLs");
        
        // Check contract is not paused
        assertFalse(leaderboard.paused(), "Contract should not be paused initially");
    }
    
    function test_deployment_roleConstants() public {
        bytes32 hookRole = leaderboard.HOOK_ROLE();
        bytes32 snapshotRole = leaderboard.SNAPSHOT_ROLE();
        bytes32 adminRole = leaderboard.DEFAULT_ADMIN_ROLE();
        
        assertEq(hookRole, keccak256("HOOK_ROLE"), "Hook role should match expected hash");
        assertEq(snapshotRole, keccak256("SNAPSHOT_ROLE"), "Snapshot role should match expected hash");
        assertEq(adminRole, 0x00, "Admin role should be zero hash");
    }
    
    function test_deployment_initialKOLMetrics() public {
        // Check that non-existent KOL has zero metrics
        (uint256 currentEpoch, , , ) = leaderboard.getEpochInfo();
        
        (
            uint256 totalTVL,
            uint256 avgTVL,
            uint256 peakTVL,
            uint256 deposits,
            uint256 withdrawals,
            uint256 uniqueUsers,
            uint256 retentionScore,
            uint256 consistencyScore,
            uint256 lastUpdateTime
        ) = leaderboard.epochMetrics(currentEpoch, kol1);
        
        assertEq(totalTVL, 0, "Initial totalTVL should be 0");
        assertEq(avgTVL, 0, "Initial avgTVL should be 0");
        assertEq(peakTVL, 0, "Initial peakTVL should be 0");
        assertEq(deposits, 0, "Initial deposits should be 0");
        assertEq(withdrawals, 0, "Initial withdrawals should be 0");
        assertEq(uniqueUsers, 0, "Initial uniqueUsers should be 0");
        assertEq(retentionScore, 0, "Initial retentionScore should be 0");
        assertEq(consistencyScore, 0, "Initial consistencyScore should be 0");
        assertEq(lastUpdateTime, 0, "Initial lastUpdateTime should be 0");
    }
    
    function test_deployment_initialStickyTVL() public {
        uint256 stickyTVL = leaderboard.getStickyTVL(kol1);
        assertEq(stickyTVL, 0, "Initial sticky TVL should be 0");
    }
    
    function test_deployment_getRankForNonExistentKOL() public {
        (uint256 currentEpoch, , , ) = leaderboard.getEpochInfo();
        (uint256 rank, ) = leaderboard.getKOLRank(kol1, currentEpoch);
        assertEq(rank, 0, "Non-existent KOL should have rank 0");
    }
    
    function test_deployment_getTopKOLsEmptyList() public {
        (uint256 currentEpoch, , , ) = leaderboard.getEpochInfo();
        (address[] memory kols, TVLLeaderboard.KOLMetrics[] memory metrics) = leaderboard.getTopKOLs(currentEpoch, 10);
        
        assertEq(kols.length, 0, "Should return empty array for no KOLs");
        assertEq(metrics.length, 0, "Should return empty metrics array for no KOLs");
    }
} 