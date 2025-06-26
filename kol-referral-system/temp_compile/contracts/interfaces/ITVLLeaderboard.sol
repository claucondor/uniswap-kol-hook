// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITVLLeaderboard {
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
    
    function updateKOLMetrics(
        address kol,
        uint256 tvlDelta,
        bool isDeposit,
        uint256 userCount
    ) external;
    
    function getTopKOLs(uint256 epoch, uint256 limit) 
        external 
        view 
        returns (address[] memory kols, KOLMetrics[] memory metrics);
    
    function getKOLRank(address kol, uint256 epoch) 
        external 
        view 
        returns (uint256 rank, KOLMetrics memory metrics);
    
    function getStickyTVL(address kol) external view returns (uint256);
    
    function currentEpoch() external view returns (uint256);
} 