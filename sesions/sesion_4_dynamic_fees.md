# Sesión 4: Dynamic Fees
## Uniswap Foundation - Atrium Academy

---

## 🎯 Objetivos de la Lección

Al finalizar esta sesión, podrás:

- ✅ **Entender cómo funcionan los dynamic fees** en Uniswap v4
- ✅ **Comprender el diseño de mecanismos** para actualizar fees en respuesta a situaciones del mundo real
- ✅ **Construir un hook de dynamic fee** que se ajusta basado en el precio promedio del gas on-chain
- ✅ **Implementar lógica de moving average** para trackear métricas on-chain
- ✅ **Usar flags de override** para modificar fees per-swap

---

## 📚 Contenido de la Sesión

### 1. Concepto de Dynamic Fees
### 2. Mecanismo de v4 para Dynamic Fees  
### 3. Implementación del Gas Price Hook
### 4. Testing y Validación

---

## 💰 Concepto de Dynamic Fees

### ¿Qué son los Dynamic Fees?

**Definición:** Pools que pueden ajustar sus fees de swap dinámicamente para mantener competitividad

**Beneficios:**
- 🏆 **Competitividad:** Ajustar fees para competir con otros pools del mismo par
- 📊 **Responsive:** Reaccionar a condiciones del mercado en tiempo real
- ⚖️ **Balance:** Favorecer a LPs o swappers según la situación

### Nuestro Proyecto: Gas Price Based Fees

**Concepto:** Ajustar fees basado en el precio promedio del gas

**Lógica:**
- ⛽ **Gas Alto (>110% promedio):** Fees más bajos (compensar costos altos)
- ⛽ **Gas Normal (90-110% promedio):** Fees base
- ⛽ **Gas Bajo (<90% promedio):** Fees más altos (aprovechar costos bajos)

**Repositorio Completo:** [gas-price-hook](https://github.com/haardikk21/gas-price-hook)

---

## ⚙️ Dynamic Fees en v4

### Arquitectura de Pool State

**Pool.State Structure:**
```solidity
struct Pool.State {
    Slot0 slot0;  // ← Aquí vive lpFee
    // ... otros campos
}
```

**Acceso a Slot0:**
```solidity
// Usando StateLibrary
Slot0 slot0 = poolManager.getSlot0(poolId);
uint24 currentFee = slot0.lpFee;
```

### Dos Enfoques para Dynamic Fees

#### 1. Update Once-per-Block o Menos Frecuente

```solidity
// Llamar desde el hook cuando sea necesario
poolManager.updateDynamicLPFee(poolKey, NEW_FEES);
```

**Implementación Interna:**
```solidity
function updateDynamicSwapFee(PoolKey memory key, uint24 newDynamicSwapFee) external {
    if (!key.fee.isDynamicFee() || msg.sender != address(key.hooks)) 
        revert UnauthorizedDynamicSwapFeeUpdate();
    
    newDynamicSwapFee.validate();
    PoolId id = key.toId();
    pools[id].setSwapFee(newDynamicSwapFee);
}
```

#### 2. Update Per-Swap (Nuestro Enfoque)

```solidity
// Retornar desde beforeSwap
function _beforeSwap(...) internal view override returns (bytes4, BeforeSwapDelta, uint24) {
    uint24 newFee = calculateDynamicFee();
    uint24 feeWithFlag = newFee | LPFeeLibrary.OVERRIDE_FEE_FLAG;
    return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, feeWithFlag);
}
```

**OVERRIDE_FEE_FLAG:** Bit 23 marcado como 1 para indicar override

---

## 🛠️ Implementación del Gas Price Hook

### Setup del Proyecto

```bash
# 1. Inicializar proyecto Foundry
forge init gas-price-dynamic-fees

# 2. Instalar dependencias
cd gas-price-dynamic-fees
forge install Uniswap/v4-periphery

# 3. Configurar remappings
forge remappings > remappings.txt

# 4. Limpiar archivos default
rm ./**/Counter*.sol
```

### Configuración foundry.toml

```toml
# foundry.toml

solc_version = '0.8.26'
evm_version = "cancun"
optimizer_runs = 800
via_ir = false
ffi = true
```

### Estructura Base del Hook

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

contract GasPriceFeesHook is BaseHook {
    using LPFeeLibrary for uint24;

    // Variables de estado para moving average
    uint128 public movingAverageGasPrice;
    uint104 public movingAverageGasPriceCount;

    // Fee base (0.5%)
    uint24 public constant BASE_FEE = 5000;

    error MustUseDynamicFee();

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        // Inicializar moving average con primera transacción
        updateMovingAverage();
    }
}
```

### Permisos del Hook

```solidity
function getHookPermissions()
    public
    pure
    override
    returns (Hooks.Permissions memory)
{
    return
        Hooks.Permissions({
            beforeInitialize: true,    // Verificar dynamic fee habilitado
            afterInitialize: false,
            beforeAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,         // Calcular y aplicar fee dinámico
            afterSwap: true,          // Actualizar moving average
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
}
```

### Funciones Helper

#### Moving Average Update

```solidity
// Actualizar nuestro moving average de gas price
function updateMovingAverage() internal {
    uint128 gasPrice = uint128(tx.gasprice);
    
    // Nueva Promedio = ((Promedio Anterior * # de Txns) + Gas Price Actual) / (# de Txns + 1)
    movingAverageGasPrice =
        ((movingAverageGasPrice * movingAverageGasPriceCount) + gasPrice) /
        (movingAverageGasPriceCount + 1);
    
    movingAverageGasPriceCount++;
}
```

#### Fee Calculation

```solidity
function getFee() internal view returns (uint24) {
    uint128 gasPrice = uint128(tx.gasprice);
    
    // Si gasPrice > movingAverage * 1.1, reducir fees a la mitad
    if (gasPrice > (movingAverageGasPrice * 11) / 10) {
        return BASE_FEE / 2;
    }
    
    // Si gasPrice < movingAverage * 0.9, duplicar fees
    if (gasPrice < (movingAverageGasPrice * 9) / 10) {
        return BASE_FEE * 2;
    }
    
    // Gas price normal, usar fee base
    return BASE_FEE;
}
```

### Hook Functions Implementation

#### beforeInitialize

```solidity
function _beforeInitialize(
    address,
    PoolKey calldata key,
    uint160
) internal pure override returns (bytes4) {
    // Verificar que el pool tiene dynamic fee habilitado
    if (!key.fee.isDynamicFee()) revert MustUseDynamicFee();
    return this.beforeInitialize.selector;
}
```

#### beforeSwap

```solidity
function _beforeSwap(
    address,
    PoolKey calldata key,
    SwapParams calldata,
    bytes calldata
) internal view override returns (bytes4, BeforeSwapDelta, uint24) {
    // Calcular fee dinámico basado en gas price actual
    uint24 fee = getFee();
    
    // Para updates a largo plazo (no per-swap), usaríamos:
    // poolManager.updateDynamicLPFee(key, fee);
    
    // Aplicar OVERRIDE_FEE_FLAG para cambio per-swap
    uint24 feeWithFlag = fee | LPFeeLibrary.OVERRIDE_FEE_FLAG;
    
    return (
        this.beforeSwap.selector,
        BeforeSwapDeltaLibrary.ZERO_DELTA,
        feeWithFlag
    );
}
```

#### afterSwap

```solidity
function _afterSwap(
    address,
    PoolKey calldata,
    SwapParams calldata,
    BalanceDelta,
    bytes calldata
) internal override returns (bytes4, int128) {
    // Actualizar moving average para próximos swaps
    updateMovingAverage();
    return (this.afterSwap.selector, 0);
}
```

---

## 🧪 Testing y Validación

### Setup del Test

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {GasPriceFeesHook} from "../src/GasPriceFeesHook.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {console} from "forge-std/console.sol";

contract TestGasPriceFeesHook is Test, Deployers {
    GasPriceFeesHook hook;
    
    function setUp() public {
        // Configuración del test
    }
}
```

### Función setUp

```solidity
function setUp() public {
    // 1. Deploy v4-core contracts
    deployFreshManagerAndRouters();
    
    // 2. Deploy, mint tokens, and approve periphery contracts
    deployMintAndApprove2Currencies();
    
    // 3. Deploy hook con flags apropiadas
    address hookAddress = address(
        uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
                Hooks.BEFORE_SWAP_FLAG |
                Hooks.AFTER_SWAP_FLAG
        )
    );
    
    // 4. Configurar gas price = 10 gwei y deploy hook
    vm.txGasPrice(10 gwei);
    deployCodeTo("GasPriceFeesHook.sol", abi.encode(manager), hookAddress);
    hook = GasPriceFeesHook(hookAddress);
    
    // 5. Inicializar pool con DYNAMIC_FEE_FLAG
    (key, ) = initPool(
        currency0,
        currency1,
        hook,
        LPFeeLibrary.DYNAMIC_FEE_FLAG, // ← Habilitar dynamic fees
        SQRT_PRICE_1_1
    );
    
    // 6. Agregar liquidez
    modifyLiquidityRouter.modifyLiquidity(
        key,
        ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 100 ether,
            salt: bytes32(0)
        }),
        ZERO_BYTES
    );
}
```

### Test Comprehensivo

```solidity
function test_feeUpdatesWithGasPrice() public {
    // Configurar parámetros de swap
    PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
        .TestSettings({takeClaims: false, settleUsingBurn: false});
    
    SwapParams memory params = SwapParams({
        zeroForOne: true,
        amountSpecified: -0.00001 ether, // Swap pequeño para evitar slippage
        sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
    });
    
    // ===== VERIFICACIÓN INICIAL =====
    // Gas price actual = 10 gwei
    // Moving average también debería ser 10 gwei
    uint128 gasPrice = uint128(tx.gasprice);
    uint128 movingAverageGasPrice = hook.movingAverageGasPrice();
    uint104 movingAverageGasPriceCount = hook.movingAverageGasPriceCount();
    
    assertEq(gasPrice, 10 gwei);
    assertEq(movingAverageGasPrice, 10 gwei);
    assertEq(movingAverageGasPriceCount, 1);
    
    // ===== TEST 1: SWAP CON GAS PRICE = PROMEDIO =====
    // Debería usar BASE_FEE ya que gas price = promedio
    uint256 balanceOfToken1Before = currency1.balanceOfSelf();
    swapRouter.swap(key, params, testSettings, ZERO_BYTES);
    uint256 balanceOfToken1After = currency1.balanceOfSelf();
    uint256 outputFromBaseFeeSwap = balanceOfToken1After - balanceOfToken1Before;
    
    assertGt(balanceOfToken1After, balanceOfToken1Before);
    
    // Moving average no debería cambiar, solo incrementar count
    movingAverageGasPrice = hook.movingAverageGasPrice();
    movingAverageGasPriceCount = hook.movingAverageGasPriceCount();
    assertEq(movingAverageGasPrice, 10 gwei);
    assertEq(movingAverageGasPriceCount, 2);
    
    // ===== TEST 2: SWAP CON GAS PRICE BAJO =====
    // Gas price = 4 gwei (< 90% del promedio)
    // Debería tener fees MÁS ALTOS
    vm.txGasPrice(4 gwei);
    balanceOfToken1Before = currency1.balanceOfSelf();
    swapRouter.swap(key, params, testSettings, ZERO_BYTES);
    balanceOfToken1After = currency1.balanceOfSelf();
    
    uint256 outputFromIncreasedFeeSwap = balanceOfToken1After - balanceOfToken1Before;
    
    assertGt(balanceOfToken1After, balanceOfToken1Before);
    
    // Moving average ahora = (10 + 10 + 4) / 3 = 8 gwei
    movingAverageGasPrice = hook.movingAverageGasPrice();
    movingAverageGasPriceCount = hook.movingAverageGasPriceCount();
    assertEq(movingAverageGasPrice, 8 gwei);
    assertEq(movingAverageGasPriceCount, 3);
    
    // ===== TEST 3: SWAP CON GAS PRICE ALTO =====
    // Gas price = 12 gwei (> 110% del promedio de 8 gwei)
    // Debería tener fees MÁS BAJOS
    vm.txGasPrice(12 gwei);
    balanceOfToken1Before = currency1.balanceOfSelf();
    swapRouter.swap(key, params, testSettings, ZERO_BYTES);
    balanceOfToken1After = currency1.balanceOfSelf();
    
    uint256 outputFromDecreasedFeeSwap = balanceOfToken1After - balanceOfToken1Before;
    
    assertGt(balanceOfToken1After, balanceOfToken1Before);
    
    // Moving average ahora = (10 + 10 + 4 + 12) / 4 = 9 gwei
    movingAverageGasPrice = hook.movingAverageGasPrice();
    movingAverageGasPriceCount = hook.movingAverageGasPriceCount();
    assertEq(movingAverageGasPrice, 9 gwei);
    assertEq(movingAverageGasPriceCount, 4);
    
    // ===== VERIFICACIÓN DE OUTPUTS =====
    console.log("Base Fee Output", outputFromBaseFeeSwap);
    console.log("Increased Fee Output", outputFromIncreasedFeeSwap);
    console.log("Decreased Fee Output", outputFromDecreasedFeeSwap);
    
    // Verificar que fees más bajos = más output tokens
    // Verificar que fees más altos = menos output tokens
    assertGt(outputFromDecreasedFeeSwap, outputFromBaseFeeSwap);
    assertGt(outputFromBaseFeeSwap, outputFromIncreasedFeeSwap);
}
```

### Ejecutar Tests

```bash
# Test básico
forge test

# Test con output verbose
forge test -vv
```

**Resultado Esperado:**
```
Ran 1 test for test/GasPriceFeesHook.t.sol:TestGasPriceFeesHook
[PASS] test_feeUpdatesWithGasPrice() (gas: 234567)

Base Fee Output 999999999999999
Increased Fee Output 999999999999998  
Decreased Fee Output 1000000000000000

Suite result: ok. 1 passed; 0 failed; 0 skipped
```

---

## 📋 Código Completo

### GasPriceFeesHook.sol Completo

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

contract GasPriceFeesHook is BaseHook {
    using LPFeeLibrary for uint24;

    // Tracking del moving average gas price
    uint128 public movingAverageGasPrice;
    uint104 public movingAverageGasPriceCount;

    // Fee base por defecto (0.5%)
    uint24 public constant BASE_FEE = 5000;

    error MustUseDynamicFee();

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        updateMovingAverage();
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: true,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function updateMovingAverage() internal {
        uint128 gasPrice = uint128(tx.gasprice);
        
        movingAverageGasPrice =
            ((movingAverageGasPrice * movingAverageGasPriceCount) + gasPrice) /
            (movingAverageGasPriceCount + 1);
        
        movingAverageGasPriceCount++;
    }

    function getFee() internal view returns (uint24) {
        uint128 gasPrice = uint128(tx.gasprice);

        // Gas alto (>110% promedio) → fees bajos
        if (gasPrice > (movingAverageGasPrice * 11) / 10) {
            return BASE_FEE / 2;
        }

        // Gas bajo (<90% promedio) → fees altos
        if (gasPrice < (movingAverageGasPrice * 9) / 10) {
            return BASE_FEE * 2;
        }

        // Gas normal → fee base
        return BASE_FEE;
    }

    function _beforeInitialize(
        address,
        PoolKey calldata key,
        uint160
    ) internal pure override returns (bytes4) {
        if (!key.fee.isDynamicFee()) revert MustUseDynamicFee();
        return this.beforeInitialize.selector;
    }

    function _beforeSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata,
        bytes calldata
    ) internal view override returns (bytes4, BeforeSwapDelta, uint24) {
        uint24 fee = getFee();
        uint24 feeWithFlag = fee | LPFeeLibrary.OVERRIDE_FEE_FLAG;
        
        return (
            this.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            feeWithFlag
        );
    }

    function _afterSwap(
        address,
        PoolKey calldata,
        SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        updateMovingAverage();
        return (this.afterSwap.selector, 0);
    }
}
```

---

## 🎯 Puntos Clave para Recordar

1. **💰 Dynamic Fees:** Pools pueden ajustar fees en tiempo real
2. **🎯 DYNAMIC_FEE_FLAG:** Debe configurarse durante inicialización del pool
3. **⚡ OVERRIDE_FEE_FLAG:** Bit 23 para aplicar fee per-swap
4. **📊 Moving Average:** Técnica para trackear métricas on-chain
5. **🔧 Hook Functions:** beforeInitialize, beforeSwap, afterSwap coordinan el flujo
6. **⛽ Gas Price:** `tx.gasprice` provee gas price actual de la transacción
7. **🧪 vm.txGasPrice:** Foundry cheat code para manipular gas price en tests

---

## 🚀 Extensiones Posibles

### Mejoras Sugeridas

✅ **Múltiples Métricas:** Combinar gas price, volatilidad, volumen
✅ **Modelos Sofisticados:** Curvas polinomiales para fee calculation
✅ **Time Decay:** Pesos decrecientes para observaciones más antiguas
✅ **Oracle Integration:** Precios externos como referencia
✅ **Circuit Breakers:** Límites máximos/mínimos para fees
✅ **Governor Controls:** Parámetros ajustables por governance

### Consideraciones de Producción

⚠️ **Economic Attacks:** Prevenir manipulación de gas price
⚠️ **MEV Protection:** Considerar impacto de MEV en fee strategy
⚠️ **LP Incentives:** Balance entre fees competitivos y revenue para LPs
⚠️ **Network Conditions:** Adaptar a diferentes L1s/L2s
⚠️ **Historical Data:** Mantener suficiente historia para accuracy

---

## 🔗 Casos de Uso Avanzados

### Dynamic Fees Basados en:

🎯 **Volatilidad:** Fees más altos durante alta volatilidad
📊 **Volumen:** Descuentos por volumen alto
⏰ **Tiempo:** Fees diferentes según hora del día
🌊 **Liquidez:** Ajustar según profundidad del pool
🔄 **Arbitraje:** Detectar y cobrar premium por oportunidades de arbitraje

---

## 📋 Próximos Pasos

Esta sesión cubre dynamic fees básicos. Las próximas sesiones cubrirán:
- Limit Orders (Parte 1 y 2) - Hooks más complejos
- Dynamic Fees avanzados (Nezlobin's Directional)
- Integración con oráculos externos
- Optimizaciones de gas y mejores prácticas

---

## 🔗 Referencias

- **Repositorio Completo:** [gas-price-hook](https://github.com/haardikk21/gas-price-hook)
- **LPFeeLibrary:** [v4-core Fee Library](https://github.com/Uniswap/v4-core/blob/main/src/libraries/LPFeeLibrary.sol)
- **Dynamic Fee Docs:** [Uniswap v4 Dynamic Fees](https://docs.uniswap.org/contracts/v4/overview)

---

*Fuente: Uniswap Foundation - Atrium Academy | v4 Hook Incubator* 