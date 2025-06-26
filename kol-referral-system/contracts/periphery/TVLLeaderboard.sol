// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract TVLLeaderboard is AccessControl, Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    bytes32 public constant HOOK_ROLE = keccak256("HOOK_ROLE");
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    
    // Configuración de épocas
    uint256 public constant EPOCH_DURATION = 30 days;
    uint256 public epochStartTime;
    uint256 public currentEpoch;
    
    // KOLs activos
    EnumerableSet.AddressSet private activeKOLs;
    
    // Métricas por KOL por época
    mapping(uint256 => mapping(address => KOLMetrics)) public epochMetrics;
    // Rankings por época (top 100)
    mapping(uint256 => address[]) public epochRankings;
    // Sticky TVL tracking para streaming rewards
    mapping(address => StickyTVLData) public stickyTVL;
    // TVL histórico por día
    mapping(address => mapping(uint256 => uint256)) public dailyTVL;
    
    struct KOLMetrics {
        uint256 totalTVL;           // TVL actual
        uint256 avgTVL;             // TVL promedio en la época
        uint256 peakTVL;            // TVL máximo alcanzado
        uint256 deposits;           // Total depositado
        uint256 withdrawals;        // Total retirado
        uint256 uniqueUsers;        // Usuarios únicos referidos
        uint256 retentionScore;     // Score de retención (0-10000 bps)
        uint256 consistencyScore;   // Score de consistencia (0-10000 bps)
        uint256 lastUpdateTime;     // Última actualización
    }
    
    struct StickyTVLData {
        uint256 totalDeposits;      // Depósitos acumulados
        uint256 totalWithdrawals;   // Retiros acumulados
        uint256 avgDailyTVL;        // TVL promedio últimos 30 días
        uint256 minDailyTVL;        // TVL mínimo últimos 30 días
        uint256 maxDailyTVL;        // TVL máximo últimos 30 días
        uint256[] last30DaysTVL;    // Array de TVL últimos 30 días
        uint256 lastUpdateTime;
    }
    
    // Events
    event EpochFinalized(
        uint256 indexed epoch, 
        address[] topKOLs,
        uint256 totalTVL
    );
    
    event MetricsUpdated(
        address indexed kol,
        uint256 indexed epoch,
        uint256 tvlDelta,
        bool isDeposit,
        uint256 newTotalTVL
    );
    
    event KOLAdded(address indexed kol, uint256 indexed epoch);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SNAPSHOT_ROLE, msg.sender);
        
        epochStartTime = block.timestamp;
        currentEpoch = 1;
    }
    
    function updateKOLMetrics(
        address kol,
        uint256 tvlDelta,
        bool isDeposit,
        uint256 userCount
    ) external onlyRole(HOOK_ROLE) whenNotPaused {
        require(kol != address(0), "Invalid KOL address");
        
        // Agregar KOL si es nuevo
        if (!activeKOLs.contains(kol)) {
            activeKOLs.add(kol);
            emit KOLAdded(kol, currentEpoch);
        }
        
        KOLMetrics storage metrics = epochMetrics[currentEpoch][kol];
        StickyTVLData storage sticky = stickyTVL[kol];
        
        // Actualizar métricas básicas
        if (isDeposit) {
            metrics.deposits += tvlDelta;
            metrics.totalTVL += tvlDelta;
            sticky.totalDeposits += tvlDelta;
        } else {
            metrics.withdrawals += tvlDelta;
            if (metrics.totalTVL >= tvlDelta) {
                metrics.totalTVL -= tvlDelta;
            } else {
                metrics.totalTVL = 0;
            }
            sticky.totalWithdrawals += tvlDelta;
        }
        
        // Actualizar peak TVL
        if (metrics.totalTVL > metrics.peakTVL) {
            metrics.peakTVL = metrics.totalTVL;
        }
        
        // Actualizar unique users
        if (userCount > metrics.uniqueUsers) {
            metrics.uniqueUsers = userCount;
        }
        
        // Actualizar tracking diario
        _updateDailyTVL(kol, metrics.totalTVL);
        
        // Calcular scores
        _calculateScores(kol);
        
        metrics.lastUpdateTime = block.timestamp;
        sticky.lastUpdateTime = block.timestamp;
        
        emit MetricsUpdated(
            kol, 
            currentEpoch, 
            tvlDelta, 
            isDeposit, 
            metrics.totalTVL
        );
    }
    
    function finalizeEpoch() external onlyRole(SNAPSHOT_ROLE) {
        require(
            block.timestamp >= epochStartTime + EPOCH_DURATION,
            "Epoch not finished"
        );
        
        // Calcular métricas finales para todos los KOLs
        address[] memory kols = activeKOLs.values();
        for (uint i = 0; i < kols.length; i++) {
            _finalizeKOLMetrics(kols[i]);
        }
        
        // Calcular rankings
        _calculateRankings(kols);
        
        // Calcular TVL total de la época
        uint256 totalEpochTVL = _calculateTotalTVL(kols);
        
        emit EpochFinalized(currentEpoch, epochRankings[currentEpoch], totalEpochTVL);
        
        // Iniciar nueva época
        currentEpoch++;
        epochStartTime = block.timestamp;
    }
    
    function _updateDailyTVL(address kol, uint256 currentTVL) internal {
        uint256 today = block.timestamp / 1 days;
        dailyTVL[kol][today] = currentTVL;
        
        StickyTVLData storage sticky = stickyTVL[kol];
        
        // Actualizar array de últimos 30 días
        if (sticky.last30DaysTVL.length < 30) {
            sticky.last30DaysTVL.push(currentTVL);
        } else {
            uint256 index = (today % 30);
            if (index < sticky.last30DaysTVL.length) {
                sticky.last30DaysTVL[index] = currentTVL;
            }
        }
        
        // Recalcular estadísticas de 30 días
        _recalculateSticky(kol);
    }
    
    function _recalculateSticky(address kol) internal {
        StickyTVLData storage sticky = stickyTVL[kol];
        uint256[] memory tvlArray = sticky.last30DaysTVL;
        
        if (tvlArray.length == 0) return;
        
        uint256 sum = 0;
        uint256 min = tvlArray[0];
        uint256 max = tvlArray[0];
        
        for (uint i = 0; i < tvlArray.length; i++) {
            sum += tvlArray[i];
            if (tvlArray[i] < min) min = tvlArray[i];
            if (tvlArray[i] > max) max = tvlArray[i];
        }
        
        sticky.avgDailyTVL = sum / tvlArray.length;
        sticky.minDailyTVL = min;
        sticky.maxDailyTVL = max;
    }
    
    function _calculateScores(address kol) internal {
        KOLMetrics storage metrics = epochMetrics[currentEpoch][kol];
        StickyTVLData storage sticky = stickyTVL[kol];
        
        // Retention Score: (deposits - withdrawals) / deposits * 10000
        if (sticky.totalDeposits > 0) {
            uint256 netTVL = sticky.totalDeposits > sticky.totalWithdrawals 
                ? sticky.totalDeposits - sticky.totalWithdrawals 
                : 0;
            metrics.retentionScore = (netTVL * 10000) / sticky.totalDeposits;
        }
        
        // Consistency Score: basado en volatilidad del TVL
        if (sticky.maxDailyTVL > 0 && sticky.avgDailyTVL > 0) {
            uint256 volatility = sticky.maxDailyTVL > sticky.minDailyTVL 
                ? ((sticky.maxDailyTVL - sticky.minDailyTVL) * 10000) / sticky.avgDailyTVL
                : 0;
            
            // Score más alto = menos volatilidad
            metrics.consistencyScore = volatility > 10000 ? 0 : 10000 - volatility;
        }
    }
    
    function _finalizeKOLMetrics(address kol) internal {
        KOLMetrics storage metrics = epochMetrics[currentEpoch][kol];
        StickyTVLData storage sticky = stickyTVL[kol];
        
        // Calcular TVL promedio de la época
        if (sticky.last30DaysTVL.length > 0) {
            metrics.avgTVL = sticky.avgDailyTVL;
        }
        
        // Scores finales
        _calculateScores(kol);
    }
    
    function _calculateRankings(address[] memory kols) internal {
        // Bubble sort optimizado para top 100
        uint256 length = kols.length;
        
        // Handle empty array case
        if (length == 0) {
            epochRankings[currentEpoch] = new address[](0);
            return;
        }
        
        for (uint i = 0; i < length - 1; i++) {
            for (uint j = 0; j < length - i - 1; j++) {
                if (_compareKOLs(kols[j], kols[j + 1])) {
                    address temp = kols[j];
                    kols[j] = kols[j + 1];
                    kols[j + 1] = temp;
                }
            }
        }
        
        // Guardar top 100
        uint256 limit = length < 100 ? length : 100;
        epochRankings[currentEpoch] = new address[](limit);
        
        for (uint i = 0; i < limit; i++) {
            epochRankings[currentEpoch][i] = kols[i];
        }
    }
    
    function _compareKOLs(address kolA, address kolB) internal view returns (bool) {
        KOLMetrics memory metricsA = epochMetrics[currentEpoch][kolA];
        KOLMetrics memory metricsB = epochMetrics[currentEpoch][kolB];
        
        // Criterio principal: TVL promedio
        if (metricsA.avgTVL != metricsB.avgTVL) {
            return metricsA.avgTVL < metricsB.avgTVL;
        }
        
        // Criterio secundario: Retention score
        if (metricsA.retentionScore != metricsB.retentionScore) {
            return metricsA.retentionScore < metricsB.retentionScore;
        }
        
        // Criterio terciario: Consistency score
        return metricsA.consistencyScore < metricsB.consistencyScore;
    }
    
    function _calculateTotalTVL(address[] memory kols) internal view returns (uint256) {
        uint256 total = 0;
        for (uint i = 0; i < kols.length; i++) {
            total += epochMetrics[currentEpoch][kols[i]].totalTVL;
        }
        return total;
    }
    
    // ========== VIEW FUNCTIONS ==========
    
    function getTopKOLs(uint256 epoch, uint256 limit) 
        external 
        view 
        returns (address[] memory kols, KOLMetrics[] memory metrics) 
    {
        address[] memory ranking = epochRankings[epoch];
        uint256 resultLimit = ranking.length < limit ? ranking.length : limit;
        
        kols = new address[](resultLimit);
        metrics = new KOLMetrics[](resultLimit);
        
        for (uint i = 0; i < resultLimit; i++) {
            kols[i] = ranking[i];
            metrics[i] = epochMetrics[epoch][ranking[i]];
        }
    }
    
    function getKOLRank(address kol, uint256 epoch) 
        external 
        view 
        returns (uint256 rank, KOLMetrics memory metrics) 
    {
        address[] memory ranking = epochRankings[epoch];
        
        for (uint i = 0; i < ranking.length; i++) {
            if (ranking[i] == kol) {
                return (i + 1, epochMetrics[epoch][kol]);
            }
        }
        
        return (0, epochMetrics[epoch][kol]);
    }
    
    function getStickyTVL(address kol) external view returns (uint256) {
        StickyTVLData storage sticky = stickyTVL[kol];
        return sticky.totalDeposits > sticky.totalWithdrawals 
            ? sticky.totalDeposits - sticky.totalWithdrawals 
            : 0;
    }
    
    function getActiveKOLs() external view returns (address[] memory) {
        return activeKOLs.values();
    }
    
    function getEpochInfo() external view returns (
        uint256 current,
        uint256 startTime,
        uint256 endTime,
        uint256 timeRemaining
    ) {
        current = currentEpoch;
        startTime = epochStartTime;
        endTime = epochStartTime + EPOCH_DURATION;
        timeRemaining = block.timestamp >= endTime ? 0 : endTime - block.timestamp;
    }
    
    // ========== ADMIN FUNCTIONS ==========
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    function emergencySetEpoch(uint256 newEpoch, uint256 newStartTime) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        currentEpoch = newEpoch;
        epochStartTime = newStartTime;
    }
    
    function forceUpdateMetrics(
        address kol,
        uint256 tvlDelta,
        bool isDeposit,
        uint256 userCount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Llamar directamente la lógica interna
        require(kol != address(0), "Invalid KOL address");
        
        // Agregar KOL si es nuevo
        if (!activeKOLs.contains(kol)) {
            activeKOLs.add(kol);
            emit KOLAdded(kol, currentEpoch);
        }
        
        KOLMetrics storage metrics = epochMetrics[currentEpoch][kol];
        StickyTVLData storage sticky = stickyTVL[kol];
        
        // Actualizar métricas básicas
        if (isDeposit) {
            metrics.deposits += tvlDelta;
            metrics.totalTVL += tvlDelta;
            sticky.totalDeposits += tvlDelta;
        } else {
            metrics.withdrawals += tvlDelta;
            if (metrics.totalTVL >= tvlDelta) {
                metrics.totalTVL -= tvlDelta;
            } else {
                metrics.totalTVL = 0;
            }
            sticky.totalWithdrawals += tvlDelta;
        }
        
        // Actualizar peak TVL
        if (metrics.totalTVL > metrics.peakTVL) {
            metrics.peakTVL = metrics.totalTVL;
        }
        
        // Actualizar unique users
        if (userCount > metrics.uniqueUsers) {
            metrics.uniqueUsers = userCount;
        }
        
        // Actualizar tracking diario
        _updateDailyTVL(kol, metrics.totalTVL);
        
        // Calcular scores
        _calculateScores(kol);
        
        metrics.lastUpdateTime = block.timestamp;
        sticky.lastUpdateTime = block.timestamp;
        
        emit MetricsUpdated(
            kol, 
            currentEpoch, 
            tvlDelta, 
            isDeposit, 
            metrics.totalTVL
        );
    }
} 