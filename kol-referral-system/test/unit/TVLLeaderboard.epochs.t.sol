// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./TVLLeaderboard.base.t.sol";

contract TVLLeaderboardEpochsTest is TVLLeaderboardBase {
    
    function test_epochInfo_initialState() public {
        (uint256 currentEpoch, uint256 startTime, uint256 endTime, uint256 timeRemaining) = leaderboard.getEpochInfo();
        
        assertEq(currentEpoch, 1, "Should start at epoch 1");
        assertEq(startTime, block.timestamp, "Start time should be current time");
        assertEq(endTime, block.timestamp + EPOCH_DURATION, "End time should be start + duration");
        assertEq(timeRemaining, EPOCH_DURATION, "Time remaining should be full duration");
    }
    
    function test_epochInfo_afterTimeAdvance() public {
        uint256 timeToAdvance = 15 days; // Half epoch
        advanceTime(timeToAdvance);
        
        (uint256 currentEpoch, uint256 startTime, uint256 endTime, uint256 timeRemaining) = leaderboard.getEpochInfo();
        
        assertEq(currentEpoch, 1, "Should still be epoch 1");
        assertEq(timeRemaining, EPOCH_DURATION - timeToAdvance, "Time remaining should be reduced");
        assertEq(endTime - block.timestamp, timeRemaining, "Time remaining calculation should be correct");
    }
    
    function test_finalizeEpoch_tooEarly() public {
        expectRevertWithMessage("Epoch not finished");
        finalizeEpochAsSnapshot();
    }
    
    function test_finalizeEpoch_onlySnapshotRole() public {
        advanceToNextEpoch();
        
        expectAccessControlError(unauthorized, leaderboard.SNAPSHOT_ROLE());
        
        vm.prank(unauthorized);
        leaderboard.finalizeEpoch();
    }
    
    function test_finalizeEpoch_success() public {
        // Add some KOLs with different TVL
        updateMetricsAsHook(kol1, 3000e18, true, 3);
        updateMetricsAsHook(kol2, 1000e18, true, 1);
        updateMetricsAsHook(kol3, 2000e18, true, 2);
        
        uint256 expectedTotalTVL = 6000e18;
        
        // Advance time to end of epoch
        advanceToNextEpoch();
        
        // Expect epoch finalized event
        vm.expectEmit(true, false, false, false);
        emit TVLLeaderboard.EpochFinalized(1, new address[](0), expectedTotalTVL);
        
        finalizeEpochAsSnapshot();
        
        // Check new epoch started
        (uint256 currentEpoch, uint256 startTime, , uint256 timeRemaining) = leaderboard.getEpochInfo();
        assertEq(currentEpoch, 2, "Should be in epoch 2");
        assertEq(startTime, block.timestamp, "New epoch should start at current time");
        assertEq(timeRemaining, EPOCH_DURATION, "New epoch should have full duration");
    }
    
    function test_finalizeEpoch_rankings() public {
        // Add KOLs with different TVL levels
        updateMetricsAsHook(kol1, 1000e18, true, 1); // Lowest
        updateMetricsAsHook(kol2, 3000e18, true, 3); // Highest
        updateMetricsAsHook(kol3, 2000e18, true, 2); // Middle
        
        advanceToNextEpoch();
        finalizeEpochAsSnapshot();
        
        // Check rankings in previous epoch (epoch 1)
        (address[] memory topKOLs, TVLLeaderboard.KOLMetrics[] memory metrics) = leaderboard.getTopKOLs(1, 10);
        
        assertEq(topKOLs.length, 3, "Should have 3 KOLs in ranking");
        assertEq(topKOLs[0], kol2, "KOL2 should be first (highest TVL)");
        assertEq(topKOLs[1], kol3, "KOL3 should be second");
        assertEq(topKOLs[2], kol1, "KOL1 should be third (lowest TVL)");
        
        // Check metrics correspond
        assertEq(metrics[0].totalTVL, 3000e18, "First place TVL should be 3000");
        assertEq(metrics[1].totalTVL, 2000e18, "Second place TVL should be 2000");
        assertEq(metrics[2].totalTVL, 1000e18, "Third place TVL should be 1000");
    }
    
    function test_getKOLRank_afterEpochFinalize() public {
        // Setup KOLs
        updateMetricsAsHook(kol1, 1000e18, true, 1);
        updateMetricsAsHook(kol2, 3000e18, true, 3);
        updateMetricsAsHook(kol3, 2000e18, true, 2);
        
        advanceToNextEpoch();
        finalizeEpochAsSnapshot();
        
        // Check individual ranks
        (uint256 rank1, ) = leaderboard.getKOLRank(kol1, 1);
        (uint256 rank2, ) = leaderboard.getKOLRank(kol2, 1);
        (uint256 rank3, ) = leaderboard.getKOLRank(kol3, 1);
        
        assertEq(rank1, 3, "KOL1 should be rank 3");
        assertEq(rank2, 1, "KOL2 should be rank 1");
        assertEq(rank3, 2, "KOL3 should be rank 2");
    }
    
    function test_getKOLRank_nonExistentKOL() public {
        updateMetricsAsHook(kol1, 1000e18, true, 1);
        
        advanceToNextEpoch();
        finalizeEpochAsSnapshot();
        
        // Check rank for KOL that doesn't exist in rankings
        (uint256 rank, ) = leaderboard.getKOLRank(kol2, 1);
        assertEq(rank, 0, "Non-existent KOL should have rank 0");
    }
    
    function test_multipleEpochs() public {
        // Epoch 1 - KOL1 is best
        updateMetricsAsHook(kol1, 3000e18, true, 3);
        updateMetricsAsHook(kol2, 1000e18, true, 1);
        
        advanceToNextEpoch();
        finalizeEpochAsSnapshot();
        
        // Check epoch 1 rankings
        (address[] memory epoch1KOLs, ) = leaderboard.getTopKOLs(1, 10);
        assertEq(epoch1KOLs[0], kol1, "KOL1 should win epoch 1");
        
        // Epoch 2 - KOL2 makes a comeback
        updateMetricsAsHook(kol2, 5000e18, true, 5);
        updateMetricsAsHook(kol1, 1000e18, true, 1);
        
        advanceToNextEpoch();
        finalizeEpochAsSnapshot();
        
        // Check epoch 2 rankings
        (address[] memory epoch2KOLs, ) = leaderboard.getTopKOLs(2, 10);
        assertEq(epoch2KOLs[0], kol2, "KOL2 should win epoch 2");
        
        // Verify epoch 1 rankings are preserved
        (address[] memory epoch1KOLsAgain, ) = leaderboard.getTopKOLs(1, 10);
        assertEq(epoch1KOLsAgain[0], kol1, "Epoch 1 rankings should be preserved");
    }
    
    function test_emergencySetEpoch_adminOnly() public {
        expectAccessControlError(unauthorized, leaderboard.DEFAULT_ADMIN_ROLE());
        
        vm.prank(unauthorized);
        leaderboard.emergencySetEpoch(5, block.timestamp);
    }
    
    function test_emergencySetEpoch_success() public {
        uint256 newEpoch = 10;
        uint256 newStartTime = block.timestamp + 1000;
        
        vm.prank(admin);
        leaderboard.emergencySetEpoch(newEpoch, newStartTime);
        
        (uint256 currentEpoch, uint256 startTime, , ) = leaderboard.getEpochInfo();
        assertEq(currentEpoch, newEpoch, "Epoch should be updated");
        assertEq(startTime, newStartTime, "Start time should be updated");
    }
    
    function test_getTopKOLs_limitedResults() public {
        // Add 5 KOLs
        updateMetricsAsHook(kol1, 1000e18, true, 1);
        updateMetricsAsHook(kol2, 2000e18, true, 2);
        updateMetricsAsHook(kol3, 3000e18, true, 3);
        updateMetricsAsHook(address(0x103), 4000e18, true, 4);
        updateMetricsAsHook(address(0x104), 5000e18, true, 5);
        
        advanceToNextEpoch();
        finalizeEpochAsSnapshot();
        
        // Request only top 3
        (address[] memory topKOLs, ) = leaderboard.getTopKOLs(1, 3);
        
        assertEq(topKOLs.length, 3, "Should return only 3 KOLs");
        assertEq(topKOLs[0], address(0x104), "Should be highest TVL first");
        assertEq(topKOLs[1], address(0x103), "Should be second highest");
        assertEq(topKOLs[2], kol3, "Should be third highest");
    }
    
    function test_epochFinalization_noKOLs() public {
        // Don't add any KOLs
        advanceToNextEpoch();
        
        vm.expectEmit(true, false, false, true);
        emit TVLLeaderboard.EpochFinalized(1, new address[](0), 0);
        
        finalizeEpochAsSnapshot();
        
        // Check empty rankings
        (address[] memory topKOLs, ) = leaderboard.getTopKOLs(1, 10);
        assertEq(topKOLs.length, 0, "Should have empty rankings");
    }
} 