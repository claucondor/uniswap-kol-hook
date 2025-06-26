// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../contracts/periphery/TVLLeaderboard.sol";

abstract contract TVLLeaderboardBase is Test {
    TVLLeaderboard public leaderboard;
    
    // Test accounts
    address public admin = address(0x1);
    address public hook = address(0x2);
    address public snapshotManager = address(0x3);
    address public kol1 = address(0x100);
    address public kol2 = address(0x101);
    address public kol3 = address(0x102);
    address public unauthorized = address(0x999);
    
    // Constants
    uint256 public constant EPOCH_DURATION = 30 days;
    uint256 public constant MAX_SCORE = 10000;
    
    function setUp() public virtual {
        // Set timestamp to 0 for predictable day calculations
        vm.warp(0);
        
        vm.startPrank(admin);
        
        // Deploy TVLLeaderboard
        leaderboard = new TVLLeaderboard();
        
        // Grant roles
        leaderboard.grantRole(leaderboard.HOOK_ROLE(), hook);
        leaderboard.grantRole(leaderboard.SNAPSHOT_ROLE(), snapshotManager);
        
        vm.stopPrank();
    }
    
    // Helper functions
    function updateMetricsAsHook(
        address kol,
        uint256 tvlDelta,
        bool isDeposit,
        uint256 userCount
    ) internal {
        vm.prank(hook);
        leaderboard.updateKOLMetrics(kol, tvlDelta, isDeposit, userCount);
    }
    
    function forceUpdateAsAdmin(
        address kol,
        uint256 tvlDelta,
        bool isDeposit,
        uint256 userCount
    ) internal {
        vm.prank(admin);
        leaderboard.forceUpdateMetrics(kol, tvlDelta, isDeposit, userCount);
    }
    
    function finalizeEpochAsSnapshot() internal {
        vm.prank(snapshotManager);
        leaderboard.finalizeEpoch();
    }
    
    // Helper for OpenZeppelin v5 AccessControl errors
    function expectAccessControlError(address account, bytes32 role) internal {
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", account, role));
    }
    
    // Helper for OpenZeppelin v5 Pausable errors
    function expectPausedError() internal {
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
    }
    
    function expectRevertWithMessage(string memory message) internal {
        vm.expectRevert(bytes(message));
    }
    
    // Advance time to next epoch
    function advanceToNextEpoch() internal {
        vm.warp(block.timestamp + EPOCH_DURATION + 1);
    }
    
    // Advance time by specific amount
    function advanceTime(uint256 timeToAdd) internal {
        vm.warp(block.timestamp + timeToAdd);
    }
    
    // Struct to mirror the contract's KOLMetrics
    struct KOLMetrics {
        uint256 totalTVL;
        uint256 avgTVL;
        uint256 peakTVL;
        uint256 deposits;
        uint256 withdrawals;
        uint256 uniqueUsers;
        uint256 retentionScore;
        uint256 consistencyScore;
        uint256 lastUpdateTime;
    }
    
    // Get current epoch metrics for a KOL
    function getCurrentMetrics(address kol) internal view returns (KOLMetrics memory) {
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
        ) = leaderboard.epochMetrics(currentEpoch, kol);
        
        return KOLMetrics({
            totalTVL: totalTVL,
            avgTVL: avgTVL,
            peakTVL: peakTVL,
            deposits: deposits,
            withdrawals: withdrawals,
            uniqueUsers: uniqueUsers,
            retentionScore: retentionScore,
            consistencyScore: consistencyScore,
            lastUpdateTime: lastUpdateTime
        });
    }
} 