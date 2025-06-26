# Sesión 5: Liquidity Operator - Limit Order Hook
## Uniswap Foundation - Atrium Academy

---

## 🎯 Objetivos de la Lección

Al finalizar esta sesión, podrás:

- ✅ **Entender qué son los limit orders** y específicamente los take-profit orders
- ✅ **Comprender el diseño de mecanismos** para implementar un orderbook a través de un hook
- ✅ **Construir un hook completo de limit orders** con todas las funcionalidades
- ✅ **Manejar tracking de tick movements** y ejecución de órdenes
- ✅ **Implementar lógica anti-recursión** para swaps dentro de hooks

---

## 📚 Contenido de la Sesión

### Parte 1: Fundamentos y Funciones Core
### Parte 2: Hook Functions y Ejecución

---

# PARTE 1: Fundamentos y Funciones Core

## 💡 Concepto de Limit Orders

### ¿Qué son los Take-Profit Orders?

**Definición:** Órdenes donde el usuario quiere vender un token cuando su precio aumenta a cierto nivel

**Ejemplo:**
- ETH trading a 3,500 USDC actualmente
- Orden: "Vender 1 ETH cuando llegue a 4,000 USDC"

### Mechanism Design

**Funcionalidades Requeridas:**
1. ✅ **Colocar órdenes** (placeOrder)
2. ✅ **Cancelar órdenes** (cancelOrder) 
3. ✅ **Reclamar tokens** después de ejecución (redeem)

**¿Cuándo se ejecutan las órdenes?**
- Cuando alguien hace un swap normal en el pool
- El swap cambia el tick del pool
- En `afterSwap` verificamos si alguna orden puede ejecutarse

### Direcciones de Take-Profit

**Pool con tokens A (Token 0) y B (Token 1) en tick 600:**

1. **Vender Token A cuando precio sube:** tick aumenta
2. **Vender Token B cuando precio sube:** tick disminuye

**Flujo de Ejecución:**
1. Alice coloca orden: vender Token A en tick > actual
2. Bob hace swap normal: compra Token A → precio sube
3. `afterSwap`: detectamos cambio de tick → ejecutamos orden de Alice
4. ¡Transacción de Bob ejecuta su swap Y la orden de Alice!

### ERC-1155 Claims System

**¿Por qué ERC-1155?**
- Múltiples usuarios pueden colocar la misma orden (mismo token, mismo tick)
- Necesitamos trackear cuántos output tokens puede reclamar cada usuario
- ERC-1155 representa "claim tokens" proporcionales a su input

---

## ⚙️ Setup del Proyecto

### Foundry Setup

```bash
# 1. Inicializar proyecto
forge init limit-orders

# 2. Instalar dependencias
cd limit-orders
forge install Uniswap/v4-periphery

# 3. Configurar remappings
forge remappings > remappings.txt

# 4. Limpiar archivos default
rm ./**/Counter*.sol
```

### foundry.toml

```toml
solc_version = '0.8.26'
evm_version = "cancun"
optimizer_runs = 800
via_ir = false
ffi = true
```

---

## 🏗️ Estructura Base del Hook

### Imports y Contract Setup

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

contract TakeProfitsHook is BaseHook, ERC1155 {
    using StateLibrary for IPoolManager;
    using FixedPointMathLib for uint256;

    // Errors
    error InvalidOrder();
    error NothingToClaim();
    error NotEnoughToClaim();

    constructor(
        IPoolManager _manager,
        string memory _uri
    ) BaseHook(_manager) ERC1155(_uri) {}
}
```

### Hook Permissions

```solidity
function getHookPermissions()
    public
    pure
    override
    returns (Hooks.Permissions memory)
{
    return
        Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,     // Inicializar tick tracking
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,           // Ejecutar órdenes pending
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
}
```

---

## 📊 Storage Mappings

### Mappings Principales

```solidity
// Órdenes pendientes: poolId => tick => direction => amount
mapping(PoolId poolId =>
    mapping(int24 tickToSellAt =>
        mapping(bool zeroForOne => uint256 inputAmount)))
public pendingOrders;

// Supply total de claim tokens por orden
mapping(uint256 orderId => uint256 claimsSupply)
public claimTokensSupply;

// Output tokens reclamables por orden ejecutada
mapping(uint256 orderId => uint256 outputClaimable)
public claimableOutputTokens;

// Último tick conocido por pool (para Parte 2)
mapping(PoolId poolId => int24 lastTick) public lastTicks;
```

---

## 🛠️ Helper Functions

### getLowerUsableTick

```solidity
function getLowerUsableTick(
    int24 tick,
    int24 tickSpacing
) private pure returns (int24) {
    // Ejemplo: tickSpacing = 60, tick = -100
    // tick usable más cercano (redondeado hacia abajo) = -120

    // intervals = -100/60 = -1 (división entera)
    int24 intervals = tick / tickSpacing;

    // Como tick < 0, redondeamos intervals hacia abajo a -2
    // Si tick > 0, intervals está bien como está
    if (tick < 0 && tick % tickSpacing != 0) intervals--; // hacia infinito negativo

    // tick usable real = intervals * tickSpacing
    // i.e. -2 * 60 = -120
    return intervals * tickSpacing;
}
```

### getOrderId

```solidity
function getOrderId(
    PoolKey calldata key,
    int24 tick,
    bool zeroForOne
) public pure returns (uint256) {
    return uint256(keccak256(abi.encode(key.toId(), tick, zeroForOne)));
}
```

---

## 📝 Función placeOrder

```solidity
function placeOrder(
    PoolKey calldata key,
    int24 tickToSellAt,
    bool zeroForOne,
    uint256 inputAmount
) external returns (int24) {
    // 1. Obtener tick usable más cercano
    int24 tick = getLowerUsableTick(tickToSellAt, key.tickSpacing);
    
    // 2. Crear orden pendiente
    pendingOrders[key.toId()][tick][zeroForOne] += inputAmount;

    // 3. Mint claim tokens al usuario
    uint256 orderId = getOrderId(key, tick, zeroForOne);
    claimTokensSupply[orderId] += inputAmount;
    _mint(msg.sender, orderId, inputAmount, "");

    // 4. Transferir input tokens al hook
    address sellToken = zeroForOne
        ? Currency.unwrap(key.currency0)
        : Currency.unwrap(key.currency1);
    IERC20(sellToken).transferFrom(msg.sender, address(this), inputAmount);

    // 5. Retornar tick donde realmente se colocó la orden
    return tick;
}
```

---

## ❌ Función cancelOrder

```solidity
function cancelOrder(
    PoolKey calldata key,
    int24 tickToSellAt,
    bool zeroForOne,
    uint256 amountToCancel
) external {
    // 1. Obtener tick usable
    int24 tick = getLowerUsableTick(tickToSellAt, key.tickSpacing);
    uint256 orderId = getOrderId(key, tick, zeroForOne);

    // 2. Verificar que tienen suficientes claim tokens
    uint256 positionTokens = balanceOf(msg.sender, orderId);
    if (positionTokens < amountToCancel) revert NotEnoughToClaim();

    // 3. Remover cantidad de órdenes pendientes
    pendingOrders[key.toId()][tick][zeroForOne] -= amountToCancel;
    
    // 4. Reducir supply de claim tokens y quemar su parte
    claimTokensSupply[orderId] -= amountToCancel;
    _burn(msg.sender, orderId, amountToCancel);

    // 5. Devolver sus input tokens
    Currency token = zeroForOne ? key.currency0 : key.currency1;
    token.transfer(msg.sender, amountToCancel);
}
```

---

## 💎 Función redeem

### Cálculo de Share del Usuario

**Fórmula:**
```
Share del usuario = claimTokens / totalInputAmountForPosition
Output tokens = totalClaimableForPosition * (claimTokens / totalInputAmountForPosition)
```

### Implementación

```solidity
function redeem(
    PoolKey calldata key,
    int24 tickToSellAt,
    bool zeroForOne,
    uint256 inputAmountToClaimFor
) external {
    // 1. Obtener tick usable
    int24 tick = getLowerUsableTick(tickToSellAt, key.tickSpacing);
    uint256 orderId = getOrderId(key, tick, zeroForOne);

    // 2. Verificar que hay output tokens reclamables
    if (claimableOutputTokens[orderId] == 0) revert NothingToClaim();

    // 3. Verificar que tienen suficientes claim tokens
    uint256 claimTokens = balanceOf(msg.sender, orderId);
    if (claimTokens < inputAmountToClaimFor) revert NotEnoughToClaim();

    uint256 totalClaimableForPosition = claimableOutputTokens[orderId];
    uint256 totalInputAmountForPosition = claimTokensSupply[orderId];

    // 4. Calcular output amount proporcional
    uint256 outputAmount = inputAmountToClaimFor.mulDivDown(
        totalClaimableForPosition,
        totalInputAmountForPosition
    );

    // 5. Actualizar estados
    claimableOutputTokens[orderId] -= outputAmount;
    claimTokensSupply[orderId] -= inputAmountToClaimFor;
    _burn(msg.sender, orderId, inputAmountToClaimFor);

    // 6. Transferir output tokens
    Currency token = zeroForOne ? key.currency1 : key.currency0;
    token.transfer(msg.sender, outputAmount);
}
```

---

## ⚡ Función executeOrder (Helper)

### Balance Settlement Helpers

```solidity
function swapAndSettleBalances(
    PoolKey calldata key,
    SwapParams memory params
) internal returns (BalanceDelta) {
    // 1. Ejecutar swap en Pool Manager
    BalanceDelta delta = poolManager.swap(key, params, "");

    // 2. Settle balances según dirección
    if (params.zeroForOne) {
        // ETH → USDC swap
        if (delta.amount0() < 0) {
            _settle(key.currency0, uint128(-delta.amount0()));
        }
        if (delta.amount1() > 0) {
            _take(key.currency1, uint128(delta.amount1()));
        }
    } else {
        // USDC → ETH swap
        if (delta.amount1() < 0) {
            _settle(key.currency1, uint128(-delta.amount1()));
        }
        if (delta.amount0() > 0) {
            _take(key.currency0, uint128(delta.amount0()));
        }
    }

    return delta;
}

function _settle(Currency currency, uint128 amount) internal {
    // Transferir tokens al PM y notificarle
    poolManager.sync(currency);
    currency.transfer(address(poolManager), amount);
    poolManager.settle();
}

function _take(Currency currency, uint128 amount) internal {
    // Tomar tokens del PM hacia nuestro hook
    poolManager.take(currency, address(this), amount);
}
```

### executeOrder Implementation

```solidity
function executeOrder(
    PoolKey calldata key,
    int24 tick,
    bool zeroForOne,
    uint256 inputAmount
) internal {
    // 1. Ejecutar swap y settle balances
    BalanceDelta delta = swapAndSettleBalances(
        key,
        SwapParams({
            zeroForOne: zeroForOne,
            // Valor negativo = "exact input for output" swap
            amountSpecified: -int256(inputAmount),
            // Sin límites de slippage (máximo slippage posible)
            sqrtPriceLimitX96: zeroForOne
                ? TickMath.MIN_SQRT_PRICE + 1
                : TickMath.MAX_SQRT_PRICE - 1
        })
    );

    // 2. Actualizar pending orders
    pendingOrders[key.toId()][tick][zeroForOne] -= inputAmount;
    
    // 3. Agregar output tokens reclamables
    uint256 orderId = getOrderId(key, tick, zeroForOne);
    uint256 outputAmount = zeroForOne
        ? uint256(int256(delta.amount1()))
        : uint256(int256(delta.amount0()));

    claimableOutputTokens[orderId] += outputAmount;
}
```

---

# PARTE 2: Hook Functions y Ejecución

## 🎯 Tracking de Tick Movements

### afterInitialize

```solidity
function _afterInitialize(
    address,
    PoolKey calldata key,
    uint160,
    int24 tick
) internal override returns (bytes4) {
    // Inicializar último tick conocido
    lastTicks[key.toId()] = tick;
    return this.afterInitialize.selector;
}
```

---

## 🔄 afterSwap - Lógica Principal

### Prevención de Recursión

**Problema:** `executeOrder` hace un swap → triggers `afterSwap` → recursión infinita

**Solución:** Verificar si `sender` es nuestro hook contract

```solidity
function _afterSwap(
    address sender,
    PoolKey calldata key,
    SwapParams calldata params,
    BalanceDelta,
    bytes calldata
) internal override returns (bytes4, int128) {
    // Si el sender es nuestro hook, no ejecutar lógica adicional
    if (sender == address(this)) return (this.afterSwap.selector, 0);

    // Intentar ejecutar órdenes pendientes
    bool tryMore = true;
    int24 currentTick;

    while (tryMore) {
        // tryMore = true si encontramos y ejecutamos una orden
        // currentTick = tick actualizado después de ejecutar orden
        (tryMore, currentTick) = tryExecutingOrders(
            key,
            !params.zeroForOne
        );
    }

    // Actualizar último tick conocido
    lastTicks[key.toId()] = currentTick;
    return (this.afterSwap.selector, 0);
}
```

### ¿Por qué `!params.zeroForOne`?

- Si Bob hace swap `zeroForOne = true` (vende Token 0)
- Precio de Token 1 sube, tick baja
- Buscamos órdenes `oneForZero` (vender Token 1)
- Por eso `executeZeroForOne = !params.zeroForOne`

---

## 🎲 tryExecutingOrders Function

### Estructura Principal

```solidity
function tryExecutingOrders(
    PoolKey calldata key,
    bool executeZeroForOne
) internal returns (bool tryMore, int24 newTick) {
    // Obtener tick actual y último conocido
    (, int24 currentTick, , ) = poolManager.getSlot0(key.toId());
    int24 lastTick = lastTicks[key.toId()];

    // Caso 1: Tick aumentó (currentTick > lastTick)
    // Caso 2: Tick disminuyó (currentTick < lastTick)
}
```

### Caso 1: Tick Aumentó

```solidity
// Tick aumentó = gente compró Token 0 vendiendo Token 1
// = Precio de Token 0 aumentó
// = Buscar órdenes para vender Token 0 (zeroForOne = true)

if (currentTick > lastTick) {
    // Loop desde lastTick hasta currentTick
    for (
        int24 tick = lastTick;
        tick < currentTick;
        tick += key.tickSpacing
    ) {
        uint256 inputAmount = pendingOrders[key.toId()][tick][executeZeroForOne];
        
        if (inputAmount > 0) {
            // Ejecutar la orden completa como un solo swap
            executeOrder(key, tick, executeZeroForOne, inputAmount);
            
            // Retornar true porque puede haber más órdenes
            // Pero necesitamos iterar desde cero ya que nuestro swap
            // puede haber movido el tick hacia abajo
            return (true, currentTick);
        }
    }
}
```

### Caso 2: Tick Disminuyó

```solidity
// Tick disminuyó = gente compró Token 1 vendiendo Token 0
// = Precio de Token 1 aumentó
// = Buscar órdenes para vender Token 1 (zeroForOne = false)

else {
    for (
        int24 tick = lastTick;
        tick > currentTick;
        tick -= key.tickSpacing
    ) {
        uint256 inputAmount = pendingOrders[key.toId()][tick][executeZeroForOne];
        
        if (inputAmount > 0) {
            executeOrder(key, tick, executeZeroForOne, inputAmount);
            return (true, currentTick);
        }
    }
}

// Si no se encontraron órdenes, retornar false
return (false, currentTick);
```

---

## 🧪 Testing Comprehensivo

### Test Setup

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import {TakeProfitsHook} from "../src/TakeProfitsHook.sol";

contract TakeProfitsHookTest is Test, Deployers, ERC1155Holder {
    using StateLibrary for IPoolManager;

    Currency token0;
    Currency token1;
    TakeProfitsHook hook;

    function setUp() public {
        // Deploy v4 core contracts
        deployFreshManagerAndRouters();

        // Deploy dos test tokens
        (token0, token1) = deployMintAndApprove2Currencies();

        // Deploy hook
        uint160 flags = uint160(
            Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG
        );
        address hookAddress = address(flags);
        deployCodeTo(
            "TakeProfitsHook.sol",
            abi.encode(manager, ""),
            hookAddress
        );
        hook = TakeProfitsHook(hookAddress);

        // Aprobar hook para gastar tokens
        MockERC20(Currency.unwrap(token0)).approve(
            address(hook),
            type(uint256).max
        );
        MockERC20(Currency.unwrap(token1)).approve(
            address(hook),
            type(uint256).max
        );

        // Inicializar pool
        (key, ) = initPool(token0, token1, hook, 3000, SQRT_PRICE_1_1);

        // Agregar liquidez en múltiples rangos
        modifyLiquidityRouter.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 10 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
        // Más rangos de liquidez...
    }
}
```

### Test: Place Order

```solidity
function test_placeOrder() public {
    int24 tick = 100;
    uint256 amount = 10e18;
    bool zeroForOne = true;

    uint256 originalBalance = token0.balanceOfSelf();

    // Colocar orden
    int24 tickLower = hook.placeOrder(key, tick, zeroForOne, amount);

    uint256 newBalance = token0.balanceOfSelf();

    // Verificar tick redondeado (tickSpacing = 60)
    assertEq(tickLower, 60);

    // Verificar balance reducido
    assertEq(originalBalance - newBalance, amount);

    // Verificar ERC-1155 tokens recibidos
    uint256 orderId = hook.getOrderId(key, tickLower, zeroForOne);
    uint256 tokenBalance = hook.balanceOf(address(this), orderId);

    assertTrue(orderId != 0);
    assertEq(tokenBalance, amount);
}
```

### Test: Cancel Order

```solidity
function test_cancelOrder() public {
    int24 tick = 100;
    uint256 amount = 10e18;
    bool zeroForOne = true;

    uint256 originalBalance = token0.balanceOfSelf();
    int24 tickLower = hook.placeOrder(key, tick, zeroForOne, amount);
    
    // Cancelar orden
    hook.cancelOrder(key, tickLower, zeroForOne, amount);

    // Verificar tokens devueltos
    uint256 finalBalance = token0.balanceOfSelf();
    assertEq(finalBalance, originalBalance);

    // Verificar ERC-1155 tokens quemados
    uint256 orderId = hook.getOrderId(key, tickLower, zeroForOne);
    uint256 tokenBalance = hook.balanceOf(address(this), orderId);
    assertEq(tokenBalance, 0);
}
```

### Test: Order Execution

```solidity
function test_orderExecute_zeroForOne() public {
    int24 tick = 100;
    uint256 amount = 1 ether;
    bool zeroForOne = true;

    // Colocar orden
    int24 tickLower = hook.placeOrder(key, tick, zeroForOne, amount);

    // Hacer swap para aumentar tick
    SwapParams memory params = SwapParams({
        zeroForOne: !zeroForOne,  // oneForZero
        amountSpecified: -1 ether,
        sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
    });

    PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
        .TestSettings({takeClaims: false, settleUsingBurn: false});

    // Ejecutar swap - afterSwap debería ejecutar nuestra orden
    swapRouter.swap(key, params, testSettings, ZERO_BYTES);

    // Verificar que orden fue ejecutada
    uint256 pendingTokensForPosition = hook.pendingOrders(
        key.toId(),
        tick,
        zeroForOne
    );
    assertEq(pendingTokensForPosition, 0);

    // Verificar output tokens disponibles
    uint256 orderId = hook.getOrderId(key, tickLower, zeroForOne);
    uint256 claimableOutputTokens = hook.claimableOutputTokens(orderId);
    uint256 hookContractToken1Balance = token1.balanceOf(address(hook));
    assertEq(claimableOutputTokens, hookContractToken1Balance);

    // Verificar que podemos redeem
    uint256 originalToken1Balance = token1.balanceOf(address(this));
    hook.redeem(key, tick, zeroForOne, amount);
    uint256 newToken1Balance = token1.balanceOf(address(this));

    assertEq(
        newToken1Balance - originalToken1Balance,
        claimableOutputTokens
    );
}
```

### Test: Múltiples Órdenes

```solidity
function test_multiple_orderExecute_zeroForOne_onlyOne() public {
    PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
        .TestSettings({takeClaims: false, settleUsingBurn: false});

    uint256 amount = 0.01 ether;

    // Colocar dos órdenes
    hook.placeOrder(key, 0, true, amount);
    hook.placeOrder(key, 60, true, amount);

    // Swap que cruza tick 60
    SwapParams memory params = SwapParams({
        zeroForOne: false,
        amountSpecified: -0.1 ether,
        sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
    });

    swapRouter.swap(key, params, testSettings, ZERO_BYTES);

    // Solo primera orden debería ejecutarse
    // porque su ejecución baja el tick
    uint256 tokensLeftToSell = hook.pendingOrders(key.toId(), 0, true);
    assertEq(tokensLeftToSell, 0);

    // Segunda orden sigue pendiente
    tokensLeftToSell = hook.pendingOrders(key.toId(), 60, true);
    assertEq(tokensLeftToSell, amount);
}
```

---

## 🎯 Puntos Clave para Recordar

1. **📊 ERC-1155 Claims:** Sistema proporcional para múltiples usuarios
2. **🎯 Tick Tracking:** `lastTicks` mapping para detectar movimientos
3. **🔄 Anti-Recursión:** Verificar `sender` para evitar loops infinitos
4. **⚡ Execution Logic:** Ejecutar una orden a la vez, re-evaluar tick
5. **🎲 Direction Logic:** `zeroForOne` swap trigger opposite direction orders
6. **💎 Balance Settlement:** `_settle` y `_take` para manejar Pool Manager
7. **🧪 ERC1155Holder:** Required para tests en Foundry

---

## 🚀 Extensiones Posibles

### Mejoras de Producción

✅ **Gas Limits:** Límite de órdenes ejecutadas por transacción
✅ **Slippage Protection:** Parámetros de slippage para órdenes
✅ **Native ETH Support:** Soporte para pools con ETH nativo
✅ **Partial Fills:** Ejecución parcial de órdenes grandes
✅ **Expiration Times:** Órdenes que expiran automáticamente
✅ **Fee Structure:** Fees por colocación/ejecución de órdenes

### Consideraciones de Seguridad

⚠️ **MEV Protection:** Protección contra sandwich attacks
⚠️ **Price Manipulation:** Validación de movimientos de tick
⚠️ **Reentrancy Guards:** Protecciones adicionales
⚠️ **Oracle Integration:** Verificación de precios justos

---

## 📋 Próximos Pasos

Esta sesión cubre un hook avanzado de limit orders. Las próximas sesiones cubrirán:
- Dynamic Fees avanzados (Nezlobin's Directional)
- Integración con oráculos externos
- Optimizaciones de gas y producción
- Casos de uso empresariales

---

## 🔗 Referencias

- **Repositorio Completo:** [take-profits-hook](https://github.com/haardikk21/take-profits-hook)
- **StateLibrary:** [Uniswap v4 State Library](https://github.com/Uniswap/v4-core/blob/main/src/libraries/StateLibrary.sol)
- **Liquidity Math:** [Detailed Explanation](https://hackmd.io/@vFMCdNzHQNqyPq_Rej0IIw/H12JlwSYA)

---

*Fuente: Uniswap Foundation - Atrium Academy | v4 Hook Incubator* 