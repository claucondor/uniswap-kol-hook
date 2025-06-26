# Instrucciones Completas: KOL TVL Referral System con Uniswap v4

## 🎯 Objetivo del Proyecto

Desarrollar un sistema de referrals gamificado donde los KOLs (Key Opinion Leaders) reciben NFTs como códigos de referral únicos. El sistema trackea TVL (Total Value Locked) generado por cada KOL y distribuye rewards mediante airdrops y streaming de tokens.

## 📋 Arquitectura del Sistema

### Componentes Principales:
1. **ReferralRegistry**: NFTs ERC-721 para KOLs (cada NFT = código de referral único)
2. **ReferralHook**: Hook de Uniswap v4 que trackea TVL por referral
3. **TVLLeaderboard**: Rankings y métricas por épocas de 30 días
4. **RewardDistributor**: Distribución de airdrops (1%) y streaming (1% over 24 meses)

### Flujo de Trabajo:
```
KOL recibe NFT → Usuario usa referral → Agrega liquidez → Hook trackea TVL → Leaderboard actualiza → Rewards distribuidos
```

---

## 🚀 FASE 1: SETUP DEL PROYECTO

### Paso 1.1: Inicialización

Ejecuta estos comandos en tu terminal:

```bash
mkdir kol-referral-system && cd kol-referral-system
npm init -y
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox @nomicfoundation/hardhat-verify
npm install --save-dev @types/node ts-node typescript solidity-coverage hardhat-gas-reporter
npm install @uniswap/v4-core @uniswap/v4-periphery @openzeppelin/contracts
npm install solmate
npx hardhat init
```

### Paso 1.2: Configuración de Hardhat

Reemplaza el contenido de `hardhat.config.ts`:

```typescript
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import "solidity-coverage";
import "hardhat-gas-reporter";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.26",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000000
      },
      evmVersion: "cancun",
      viaIR: true
    }
  },
  networks: {
    hardhat: {
      forking: {
        url: process.env.MAINNET_RPC_URL || "https://rpc.ankr.com/eth",
        blockNumber: 18500000
      }
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "https://rpc.sepolia.org",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    }
  },
  gasReporter: {
    enabled: true,
    currency: "USD"
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  }
};

export default config;
```

### Paso 1.3: Estructura de Directorios

Crea esta estructura:

```bash
mkdir -p contracts/{core,hooks,periphery,libraries,interfaces}
mkdir -p test/{unit,integration,utils}
mkdir -p scripts/{deploy,setup,maintenance}
mkdir -p docs
```

---

## 🏗️ FASE 2: IMPLEMENTACIÓN DE CONTRATOS

### Paso 2.1: ReferralRegistry.sol (NFT System)

Crea `contracts/core/ReferralRegistry.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract ReferralRegistry is 
    ERC721, 
    ERC721Enumerable, 
    ERC721URIStorage, 
    AccessControl, 
    Pausable 
{
    using Counters for Counters.Counter;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    Counters.Counter private _tokenIds;
    
    // Mappings principales
    mapping(uint256 => ReferralInfo) public referralInfo;
    mapping(address => uint256[]) public kolTokens;
    mapping(address => uint256) public userReferralToken;
    mapping(string => uint256) public codeToTokenId;
    
    struct ReferralInfo {
        string referralCode;
        address kol;
        uint256 totalTVL;
        uint256 uniqueUsers;
        uint256 createdAt;
        bool isActive;
        string socialHandle; // Twitter, Discord, etc.
        string metadata; // IPFS hash for additional data
    }
    
    // Events
    event ReferralMinted(
        uint256 indexed tokenId,
        address indexed kol,
        string referralCode,
        string socialHandle
    );
    
    event UserReferred(
        address indexed user,
        uint256 indexed tokenId,
        address indexed kol
    );
    
    event ReferralDeactivated(uint256 indexed tokenId);
    event TVLUpdated(uint256 indexed tokenId, uint256 newTVL);
    
    constructor() ERC721("KOL Referral NFT", "KOLREF") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }
    
    function mintReferral(
        address kol,
        string memory referralCode,
        string memory socialHandle,
        string memory metadataURI
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256) {
        require(codeToTokenId[referralCode] == 0, "Code already exists");
        require(kol != address(0), "Invalid KOL address");
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        _safeMint(kol, newTokenId);
        _setTokenURI(newTokenId, metadataURI);
        
        referralInfo[newTokenId] = ReferralInfo({
            referralCode: referralCode,
            kol: kol,
            totalTVL: 0,
            uniqueUsers: 0,
            createdAt: block.timestamp,
            isActive: true,
            socialHandle: socialHandle,
            metadata: metadataURI
        });
        
        codeToTokenId[referralCode] = newTokenId;
        kolTokens[kol].push(newTokenId);
        
        emit ReferralMinted(newTokenId, kol, referralCode, socialHandle);
        
        return newTokenId;
    }
    
    function setUserReferral(
        address user,
        string memory referralCode
    ) external returns (uint256 tokenId, address kol) {
        require(user != address(0), "Invalid user address");
        require(userReferralToken[user] == 0, "User already referred");
        
        tokenId = codeToTokenId[referralCode];
        require(tokenId != 0, "Invalid referral code");
        require(referralInfo[tokenId].isActive, "Referral inactive");
        
        userReferralToken[user] = tokenId;
        referralInfo[tokenId].uniqueUsers++;
        kol = referralInfo[tokenId].kol;
        
        emit UserReferred(user, tokenId, kol);
    }
    
    function getUserReferralInfo(address user) 
        external 
        view 
        returns (uint256 tokenId, address kol, string memory referralCode) 
    {
        tokenId = userReferralToken[user];
        if (tokenId == 0) return (0, address(0), "");
        
        ReferralInfo memory info = referralInfo[tokenId];
        return (tokenId, info.kol, info.referralCode);
    }
    
    function updateTVL(uint256 tokenId, uint256 newTVL) external {
        require(hasRole(MINTER_ROLE, msg.sender), "Not authorized");
        require(_exists(tokenId), "Token does not exist");
        
        referralInfo[tokenId].totalTVL = newTVL;
        emit TVLUpdated(tokenId, newTVL);
    }
    
    function deactivateReferral(uint256 tokenId) external {
        require(
            ownerOf(tokenId) == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        
        referralInfo[tokenId].isActive = false;
        emit ReferralDeactivated(tokenId);
    }
    
    function getKOLTokens(address kol) external view returns (uint256[] memory) {
        return kolTokens[kol];
    }
    
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    // Override functions required by Solidity
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        
        // Update KOL mappings on transfer
        if (from != address(0) && to != address(0)) {
            // Remove from old owner
            uint256[] storage fromTokens = kolTokens[from];
            for (uint i = 0; i < fromTokens.length; i++) {
                if (fromTokens[i] == tokenId) {
                    fromTokens[i] = fromTokens[fromTokens.length - 1];
                    fromTokens.pop();
                    break;
                }
            }
            
            // Add to new owner
            kolTokens[to].push(tokenId);
            
            // Update referral info
            referralInfo[tokenId].kol = to;
        }
    }
    
    function _burn(uint256 tokenId) 
        internal 
        override(ERC721, ERC721URIStorage) 
    {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

### Paso 2.2: Interfaces Necesarias

Crea `contracts/interfaces/IReferralRegistry.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IReferralRegistry {
    struct ReferralInfo {
        string referralCode;
        address kol;
        uint256 totalTVL;
        uint256 uniqueUsers;
        uint256 createdAt;
        bool isActive;
        string socialHandle;
        string metadata;
    }
    
    function getUserReferralInfo(address user) 
        external 
        view 
        returns (uint256 tokenId, address kol, string memory referralCode);
    
    function updateTVL(uint256 tokenId, uint256 newTVL) external;
    
    function referralInfo(uint256 tokenId) 
        external 
        view 
        returns (ReferralInfo memory);
}
```

---

## 🏆 FASE 3: SISTEMA DE LEADERBOARD

### Paso 3.1: TVLLeaderboard.sol

Crea `contracts/periphery/TVLLeaderboard.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

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
}
```

### Paso 3.2: Interface para TVLLeaderboard

Crea `contracts/interfaces/ITVLLeaderboard.sol`:

```solidity
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
```

---

## 🪝 FASE 4: HOOK DE UNISWAP V4

### Paso 4.1: ReferralHook.sol

Crea `contracts/hooks/ReferralHook.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {Position} from "v4-core/libraries/Position.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import "../interfaces/IReferralRegistry.sol";
import "../interfaces/ITVLLeaderboard.sol";

contract ReferralHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    using FixedPointMathLib for uint256;
    
    // Contratos principales
    IReferralRegistry public immutable referralRegistry;
    ITVLLeaderboard public immutable tvlLeaderboard;
    
    // Tracking de posiciones por usuario
    mapping(PoolId => mapping(address => UserPosition)) public userPositions;
    // TVL por KOL por pool
    mapping(address => mapping(PoolId => uint256)) public kolPoolTVL;
    // Total TVL por KOL
    mapping(address => uint256) public kolTotalTVL;
    // Contador de usuarios únicos por KOL
    mapping(address => mapping(address => bool)) public kolUserSeen;
    mapping(address => uint256) public kolUniqueUsers;
    
    struct UserPosition {
        uint256 liquidity;
        address referredBy;
        uint256 depositTime;
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        int24 tickLower;
        int24 tickUpper;
    }
    
    // Events
    event ReferralTracked(
        address indexed user,
        address indexed kol,
        PoolId indexed poolId,
        uint256 tvlDelta,
        bool isDeposit
    );
    
    event TVLUpdated(
        address indexed kol,
        PoolId indexed poolId,
        uint256 newPoolTVL,
        uint256 newTotalTVL
    );
    
    error UnauthorizedCaller();
    error InvalidReferral();
    
    constructor(
        IPoolManager _manager,
        IReferralRegistry _referralRegistry,
        ITVLLeaderboard _tvlLeaderboard
    ) BaseHook(_manager) {
        referralRegistry = _referralRegistry;
        tvlLeaderboard = _tvlLeaderboard;
    }
    
    function getHookPermissions() 
        public 
        pure 
        override 
        returns (Hooks.Permissions memory) 
    {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: true,
            beforeSwap: false,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
    
    // ========== LIQUIDITY HOOKS ==========
    
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4) {
        PoolId poolId = key.toId();
        
        // Verificar si el usuario tiene referral
        (uint256 tokenId, address kol, ) = referralRegistry.getUserReferralInfo(sender);
        
        if (kol != address(0)) {
            // Actualizar posición del usuario
            UserPosition storage position = userPositions[poolId][sender];
            position.referredBy = kol;
            position.tickLower = params.tickLower;
            position.tickUpper = params.tickUpper;
            
            // Trackear usuario único
            if (!kolUserSeen[kol][sender]) {
                kolUserSeen[kol][sender] = true;
                kolUniqueUsers[kol]++;
            }
        }
        
        return this.beforeAddLiquidity.selector;
    }
    
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, BalanceDelta) {
        if (params.liquidityDelta <= 0) {
            return (this.afterAddLiquidity.selector, BalanceDelta(0, 0));
        }
        
        PoolId poolId = key.toId();
        UserPosition storage position = userPositions[poolId][sender];
        address kol = position.referredBy;
        
        if (kol != address(0)) {
            // Calcular valor del TVL agregado
            uint256 tvlAdded = _calculateTVLFromDelta(key, delta);
            
            // Actualizar posición del usuario
            position.liquidity += uint256(params.liquidityDelta);
            position.totalDeposited += tvlAdded;
            position.depositTime = block.timestamp;
            
            // Actualizar TVL del KOL
            kolPoolTVL[kol][poolId] += tvlAdded;
            kolTotalTVL[kol] += tvlAdded;
            
            // Actualizar NFT en registry
            (uint256 tokenId, , ) = referralRegistry.getUserReferralInfo(sender);
            if (tokenId != 0) {
                referralRegistry.updateTVL(tokenId, kolTotalTVL[kol]);
            }
            
            // Notificar al leaderboard
            tvlLeaderboard.updateKOLMetrics(
                kol,
                tvlAdded,
                true, // isDeposit
                kolUniqueUsers[kol]
            );
            
            emit ReferralTracked(sender, kol, poolId, tvlAdded, true);
            emit TVLUpdated(kol, poolId, kolPoolTVL[kol][poolId], kolTotalTVL[kol]);
        }
        
        return (this.afterAddLiquidity.selector, BalanceDelta(0, 0));
    }
    
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4) {
        return this.beforeRemoveLiquidity.selector;
    }
    
    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, BalanceDelta) {
        if (params.liquidityDelta >= 0) {
            return (this.afterRemoveLiquidity.selector, BalanceDelta(0, 0));
        }
        
        PoolId poolId = key.toId();
        UserPosition storage position = userPositions[poolId][sender];
        address kol = position.referredBy;
        
        if (kol != address(0)) {
            // Calcular valor removido
            uint256 tvlRemoved = _calculateTVLFromDelta(key, delta);
            
            // Actualizar posición del usuario
            uint256 liquidityRemoved = uint256(-params.liquidityDelta);
            if (position.liquidity >= liquidityRemoved) {
                position.liquidity -= liquidityRemoved;
            } else {
                position.liquidity = 0;
            }
            position.totalWithdrawn += tvlRemoved;
            
            // Actualizar TVL del KOL
            if (kolPoolTVL[kol][poolId] >= tvlRemoved) {
                kolPoolTVL[kol][poolId] -= tvlRemoved;
            } else {
                kolPoolTVL[kol][poolId] = 0;
            }
            
            if (kolTotalTVL[kol] >= tvlRemoved) {
                kolTotalTVL[kol] -= tvlRemoved;
            } else {
                kolTotalTVL[kol] = 0;
            }
            
            // Actualizar NFT en registry
            (uint256 tokenId, , ) = referralRegistry.getUserReferralInfo(sender);
            if (tokenId != 0) {
                referralRegistry.updateTVL(tokenId, kolTotalTVL[kol]);
            }
            
            // Notificar al leaderboard
            tvlLeaderboard.updateKOLMetrics(
                kol,
                tvlRemoved,
                false, // isDeposit = false
                kolUniqueUsers[kol]
            );
            
            emit ReferralTracked(sender, kol, poolId, tvlRemoved, false);
            emit TVLUpdated(kol, poolId, kolPoolTVL[kol][poolId], kolTotalTVL[kol]);
        }
        
        return (this.afterRemoveLiquidity.selector, BalanceDelta(0, 0));
    }
    
    // ========== HELPER FUNCTIONS ==========
    
    function _calculateTVLFromDelta(
        PoolKey calldata key,
        BalanceDelta delta
    ) internal view returns (uint256) {
        // Simplificado: suma absoluta de ambos tokens
        // En producción: usar oracle para conversión a USD
        
        int256 amount0 = delta.amount0();
        int256 amount1 = delta.amount1();
        
        uint256 tvl = 0;
        
        // Tomar valores absolutos y sumar
        if (amount0 > 0) {
            tvl += uint256(amount0);
        } else if (amount0 < 0) {
            tvl += uint256(-amount0);
        }
        
        if (amount1 > 0) {
            tvl += uint256(amount1);
        } else if (amount1 < 0) {
            tvl += uint256(-amount1);
        }
        
        return tvl;
    }
    
    // ========== VIEW FUNCTIONS ==========
    
    function getKOLStats(address kol) 
        external 
        view 
        returns (
            uint256 totalTVL,
            uint256 uniqueUsers,
            uint256 activePools
        ) 
    {
        totalTVL = kolTotalTVL[kol];
        uniqueUsers = kolUniqueUsers[kol];
        
        // Contar pools activos (con TVL > 0)
        // Nota: En implementación real, mantener contador separado
        activePools = 0;
    }
    
    function getUserPosition(PoolId poolId, address user) 
        external 
        view 
        returns (UserPosition memory) 
    {
        return userPositions[poolId][user];
    }
    
    function getKOLPoolTVL(address kol, PoolId poolId) 
        external 
        view 
        returns (uint256) 
    {
        return kolPoolTVL[kol][poolId];
    }
    
    // ========== ADMIN FUNCTIONS ==========
    
    function recalculateKOLTVL(address kol) external {
        // Función para recalcular TVL en caso de inconsistencias
        // Solo callable por admin del registry
        require(
            referralRegistry.hasRole(
                referralRegistry.DEFAULT_ADMIN_ROLE(), 
                msg.sender
            ),
            "Not authorized"
        );
        
        // Implementar lógica de recálculo si es necesario
        // Por ahora, mantener tracking en tiempo real
    }
}
```

### Paso 4.2: Utilidades para Hook Address Mining

Crea `contracts/libraries/HookMiner.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Hooks} from "v4-core/libraries/Hooks.sol";

library HookMiner {
    // Flags para ReferralHook
    uint160 constant FLAG_BEFORE_ADD_LIQUIDITY = 1 << 5;
    uint160 constant FLAG_AFTER_ADD_LIQUIDITY = 1 << 6;
    uint160 constant FLAG_BEFORE_REMOVE_LIQUIDITY = 1 << 7;
    uint160 constant FLAG_AFTER_REMOVE_LIQUIDITY = 1 << 8;
    
    uint160 constant REFERRAL_HOOK_FLAGS = 
        FLAG_BEFORE_ADD_LIQUIDITY |
        FLAG_AFTER_ADD_LIQUIDITY |
        FLAG_BEFORE_REMOVE_LIQUIDITY |
        FLAG_AFTER_REMOVE_LIQUIDITY;
    
    function find(
        address deployer,
        uint160 flags,
        bytes memory creationCode,
        bytes memory constructorArgs
    ) external view returns (address, bytes32) {
        address hookAddress;
        bytes32 salt;
        
        for (uint256 i = 0; i < 100000; i++) {
            salt = keccak256(abi.encodePacked(i));
            hookAddress = computeAddress(deployer, salt, creationCode, constructorArgs);
            
            if (uint160(hookAddress) & (2 ** 19 - 1) == flags) {
                return (hookAddress, salt);
            }
        }
        
        revert("HookMiner: could not find hook address");
    }
    
    function computeAddress(
        address deployer,
        bytes32 salt,
        bytes memory creationCode,
        bytes memory constructorArgs
    ) public pure returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            deployer,
                            salt,
                            keccak256(abi.encodePacked(creationCode, constructorArgs))
                        )
                    )
                )
            )
        );
    }
}
