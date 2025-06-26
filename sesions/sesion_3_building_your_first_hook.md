# Sesión 3: Construyendo tu Primer Hook
## Uniswap Foundation - Atrium Academy

---

## 🎯 Objetivos de la Lección

Al finalizar esta sesión, podrás:

- ✅ **Configurar un nuevo proyecto Foundry** para construir hooks
- ✅ **Minar direcciones de hook apropiadas** que cumplan los requisitos de bitmap
- ✅ **Crear un hook simple** que emite tokens ERC-1155 como puntos por ciertos tipos de intercambios
- ✅ **Escribir tests en Solidity** usando Foundry
- ✅ **Entender el flujo completo** de desarrollo de hooks

---

## 📚 Contenido de la Sesión

### 1. Diseño del Mecanismo
### 2. Configuración del Proyecto
### 3. Estructura del Hook
### 4. Implementación del Código
### 5. Testing y Validación

---

## 🎨 Diseño del Mecanismo

### Concepto del Proyecto

**Objetivo:** Crear un hook que incentive compras de un token memecoin

**Características:**
- Pool objetivo: ETH ↔ TOKEN
- Incentivo: Cuando un usuario compra TOKEN con ETH
- Recompensa: Tokens POINTS (ERC-1155) equivalentes al 20% del ETH gastado

### Análisis de Hook Functions

**Opciones Disponibles:**
```solidity
beforeSwap vs afterSwap
```

#### Comparación de Firmas

```solidity
// beforeSwap
beforeSwap(
    address sender, 
    PoolKey calldata key, 
    IPoolManager.SwapParams calldata params, 
    bytes calldata hookData
)

// afterSwap - ¡Tiene BalanceDelta adicional!
afterSwap(
    address sender,
    PoolKey calldata key, 
    IPoolManager.SwapParams calldata params, 
    BalanceDelta delta,  // ← Esta es la clave
    bytes calldata hookData
)
```

### Tipos de Swaps

#### 1. Exact Input for Output
```solidity
amountSpecified = -1 ether  // Negativo = "dinero saliendo de mi wallet"
// "Quiero vender exactamente 1 ETH por alguna cantidad de USDC"
```

#### 2. Exact Output for Input  
```solidity
amountSpecified = +4000 ether  // Positivo = "dinero entrando a mi wallet"
// "Quiero exactamente 4000 USDC, puedo gastar hasta 1.5 ETH"
```

### ¿Por qué afterSwap?

**Problema con beforeSwap:**
- No sabemos la cantidad exacta de ETH gastado
- Solo conocemos los parámetros de entrada, no los resultados

**Solución con afterSwap:**
- `BalanceDelta delta` contiene las cantidades exactas intercambiadas
- Calculación precisa de puntos a otorgar

---

## ⚙️ Configuración del Proyecto

### Instalación de Foundry

**Prerrequisito:** [Instalación de Foundry](https://book.getfoundry.sh/getting-started/installation)

### Inicialización del Proyecto

```bash
# 1. Crear nuevo proyecto
forge init points-hook

# 2. Instalar dependencias de Uniswap v4
forge install https://github.com/Uniswap/v4-periphery

# 3. Configurar remappings
forge remappings > remappings.txt

# 4. Limpiar archivos por defecto
rm ./**/Counter*.sol
```

### Configuración de foundry.toml

```toml
# foundry.toml

solc_version = '0.8.26'
evm_version = "cancun"       # Para transient storage
optimizer_runs = 800
via_ir = false
ffi = true
```

**Razón:** v4 usa transient storage (EIP-1153) disponible desde Cancun

---

## 🏗️ Estructura del Hook

### Imports y Herencias

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";

import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

contract PointsHook is BaseHook, ERC1155 {
    // Implementación aquí...
}
```

### Constructor y Permisos

```solidity
contract PointsHook is BaseHook, ERC1155 {
    constructor(
        IPoolManager _manager
    ) BaseHook(_manager) {}

    // Configurar permisos del hook
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,          // ← Solo esta función
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    // Implementar función ERC1155 requerida
    function uri(uint256) public view virtual override returns (string memory) {
        return "https://api.example.com/token/{id}";
    }
}
```

---

## 💻 Implementación del Código

### Función Helper: _assignPoints

```solidity
function _assignPoints(
    PoolId poolId,
    bytes calldata hookData,
    uint256 points
) internal {
    // Si no hay hookData, no se asignan puntos
    if (hookData.length == 0) return;

    // Extraer dirección del usuario de hookData
    address user = abi.decode(hookData, (address));

    // Si hookData está mal formateado o user es address(0)
    if (user == address(0)) return;

    // Acuñar puntos al usuario
    uint256 poolIdUint = uint256(PoolId.unwrap(poolId));
    _mint(user, poolIdUint, points, "");
}
```

**¿Por qué hookData?**
- `address sender` en hooks = dirección del router contract
- Necesitamos la dirección real del usuario
- Usuario pasa su dirección via `abi.encode(userAddress)`

### Implementación de afterSwap

```solidity
function _afterSwap(
    address,
    PoolKey calldata key,
    SwapParams calldata swapParams,
    BalanceDelta delta,
    bytes calldata hookData
) internal override returns (bytes4, int128) {
    // 1. Verificar que es un pool ETH-TOKEN
    if (!key.currency0.isAddressZero()) return (this.afterSwap.selector, 0);

    // 2. Verificar que es compra de TOKEN con ETH (zeroForOne = true)
    if (!swapParams.zeroForOne) return (this.afterSwap.selector, 0);

    // 3. Calcular cantidad de ETH gastado
    // En swap zeroForOne, amount0 es negativo (ETH saliendo)
    // Por eso usamos -delta.amount0() para obtener valor positivo
    uint256 ethSpendAmount = uint256(int256(-delta.amount0()));
    
    // 4. Calcular puntos (20% = dividir por 5)
    uint256 pointsForSwap = ethSpendAmount / 5;

    // 5. Acuñar puntos
    _assignPoints(key.toId(), hookData, pointsForSwap);

    return (this.afterSwap.selector, 0);
}
```

### Explicación de BalanceDelta

**¿Qué es BalanceDelta?**
- Representa cambios en balances desde la perspectiva del usuario
- `amount0()` = cambio en Token 0 (ETH)
- `amount1()` = cambio en Token 1 (TOKEN)

**Para swap ETH → TOKEN:**
- `delta.amount0()` = negativo (ETH saliendo del usuario)
- `delta.amount1()` = positivo (TOKEN entrando al usuario)

---

## 🎯 Direcciones de Hook Contract

### El Problema del Address Bitmap

**Recordatorio:** Las direcciones de hook codifican qué funciones implementan

### Minería de Direcciones

#### Concepto Básico
```solidity
// Para obtener dirección con bit específico activado:
uint160 flags = uint160(1 << bitPosition);
address hookAddress = address(flags);
```

#### Ejemplos Prácticos

**Bit 0 activado:**
```solidity
uint160 flags = uint160(1 << 0);  // = 1
address myAddr = address(flags);  // = 0x0000...0001
```

**Bit 3 activado:**
```solidity
uint160 flags = uint160(1 << 3);  // = 8
address myAddr = address(flags);  // = 0x0000...0008
```

**Múltiples bits:**
```solidity
uint160 flags = uint160(1 << 0 | 1 << 3);  // = 9
address myAddr = address(flags);  // = 0x0000...0009
```

#### Para nuestro Hook

```solidity
// afterSwap flag
uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
address hookAddress = address(flags);
```

---

## 🧪 Testing y Validación

### Estructura del Test

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

// ... más imports

import {PointsHook} from "../src/PointsHook.sol";

contract TestPointsHook is Test, Deployers, ERC1155TokenReceiver {
    MockERC20 token;
    
    Currency ethCurrency = Currency.wrap(address(0));
    Currency tokenCurrency;
    
    PointsHook hook;
    
    function setUp() public {
        // Configuración del test
    }
}
```

### Función setUp

```solidity
function setUp() public {
    // 1. Deploy PoolManager y Router contracts
    deployFreshManagerAndRouters();

    // 2. Deploy nuestro TOKEN contract
    token = new MockERC20("Test Token", "TEST", 18);
    tokenCurrency = Currency.wrap(address(token));

    // 3. Mint TOKEN supply
    token.mint(address(this), 1000 ether);
    token.mint(address(1), 1000 ether);

    // 4. Deploy hook con address apropiada
    uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
    deployCodeTo("PointsHook.sol", abi.encode(manager), address(flags));
    hook = PointsHook(address(flags));

    // 5. Aprobar TOKEN para routers
    token.approve(address(swapRouter), type(uint256).max);
    token.approve(address(modifyLiquidityRouter), type(uint256).max);

    // 6. Inicializar pool
    (key, ) = initPool(
        ethCurrency,        // Currency 0 = ETH
        tokenCurrency,      // Currency 1 = TOKEN
        hook,              // Hook Contract
        3000,              // Swap Fees
        SQRT_PRICE_1_1     // Initial Sqrt(P) = 1
    );

    // 7. Agregar liquidez al pool
    uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
    uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);

    uint256 ethToAdd = 0.003 ether;
    uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
        SQRT_PRICE_1_1,
        sqrtPriceAtTickUpper,
        ethToAdd
    );

    modifyLiquidityRouter.modifyLiquidity{value: ethToAdd}(
        key,
        ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: int256(uint256(liquidityDelta)),
            salt: bytes32(0)
        }),
        ZERO_BYTES
    );
}
```

### Test de Swap

```solidity
function test_swap() public {
    // 1. Obtener balance inicial de puntos
    uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
    uint256 pointsBalanceOriginal = hook.balanceOf(address(this), poolIdUint);

    // 2. Preparar hookData con dirección del usuario
    bytes memory hookData = abi.encode(address(this));

    // 3. Realizar swap: 0.001 ETH por TOKEN
    // Esperamos recibir 20% de 0.001 * 10^18 = 2 * 10^14 puntos
    swapRouter.swap{value: 0.001 ether}(
        key,
        SwapParams({
            zeroForOne: true,                                // ETH → TOKEN
            amountSpecified: -0.001 ether,                  // Exact input swap
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1  // Slippage limit
        }),
        PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        }),
        hookData
    );

    // 4. Verificar que recibimos los puntos correctos
    uint256 pointsBalanceAfterSwap = hook.balanceOf(address(this), poolIdUint);
    assertEq(pointsBalanceAfterSwap - pointsBalanceOriginal, 2 * 10 ** 14);
}
```

### Ejecutar Tests

```bash
forge test
```

**Resultado Esperado:**
```
Ran 1 test for test/PointsHook.t.sol:TestPointsHook
[PASS] test_swap() (gas: 162740)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 7.18ms

Ran 1 test suite: 1 tests passed, 0 failed, 0 skipped
```

---

## 📋 Código Completo

### PointsHook.sol Completo

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";

import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

contract PointsHook is BaseHook, ERC1155 {
    constructor(
        IPoolManager _manager
    ) BaseHook(_manager) {}

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function uri(uint256) public view virtual override returns (string memory) {
        return "https://api.example.com/token/{id}";
    }

    function _assignPoints(
        PoolId poolId,
        bytes calldata hookData,
        uint256 points
    ) internal {
        if (hookData.length == 0) return;

        address user = abi.decode(hookData, (address));

        if (user == address(0)) return;

        uint256 poolIdUint = uint256(PoolId.unwrap(poolId));
        _mint(user, poolIdUint, points, "");
    }

    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        // Verificar que es pool ETH-TOKEN
        if (!key.currency0.isAddressZero()) return (this.afterSwap.selector, 0);

        // Verificar que es compra de TOKEN con ETH
        if (!swapParams.zeroForOne) return (this.afterSwap.selector, 0);

        // Calcular ETH gastado y puntos a otorgar
        uint256 ethSpendAmount = uint256(int256(-delta.amount0()));
        uint256 pointsForSwap = ethSpendAmount / 5; // 20%

        // Acuñar puntos
        _assignPoints(key.toId(), hookData, pointsForSwap);

        return (this.afterSwap.selector, 0);
    }
}
```

---

## 🎯 Puntos Clave para Recordar

1. **🎨 Diseño Primero:** Analizar qué hook functions necesitas antes de programar
2. **📊 BalanceDelta:** afterSwap te da las cantidades exactas intercambiadas
3. **🎯 Address Mining:** Las direcciones de hook deben tener bits específicos activados
4. **📝 hookData:** Mecanismo para pasar datos adicionales a los hooks
5. **🧪 Testing:** Foundry permite tests en Solidity con utilidades de Uniswap
6. **🔧 Foundry Config:** Configurar correctamente para transient storage (Cancun)
7. **✅ Return Values:** Los hooks deben retornar su selector de función

---

## 🚀 Extensiones Posibles

### Mejoras Sugeridas

✅ **Múltiples Pools:** Soportar diferentes pools con diferentes rates de puntos
✅ **Time Locks:** Puntos que se desbloquean gradualmente
✅ **Multipliers:** Bonificaciones por volumen o frecuencia
✅ **Governance:** Votación usando puntos acumulados
✅ **Burning Mechanism:** Quemar puntos por beneficios especiales

### Consideraciones de Producción

⚠️ **Edge Cases:** Manejar valores extremos y errores
⚠️ **Gas Optimization:** Minimizar costos de gas
⚠️ **Security:** Auditorías y testing exhaustivo
⚠️ **Oracle Integration:** Precios justos y anti-manipulación
⚠️ **Upgradeability:** Mecanismos de actualización

---

## 📋 Próximos Pasos

Esta sesión cubre la construcción básica de hooks. Las próximas sesiones cubrirán:
- Hooks más complejos con múltiples funciones
- Integración con oráculos y feeds de precios
- Optimizaciones de gas y mejores prácticas
- Casos de uso avanzados (limit orders, dynamic fees, etc.)

---

## 🔗 Referencias

- **Repositorio Completo:** [points-hook](https://github.com/haardikk21/points-hook)
- **Foundry Book:** [Foundry Documentation](https://book.getfoundry.sh/)
- **Uniswap v4 Docs:** [Developer Documentation](https://docs.uniswap.org/contracts/v4/overview)
- **Liquidity Math:** [Detailed Explanation](https://hackmd.io/@vFMCdNzHQNqyPq_Rej0IIw/H12JlwSYA)

---

*Fuente: Uniswap Foundation - Atrium Academy | v4 Hook Incubator* 