# Sesión 1: Uniswap v4 - Arquitectura y Hooks
## Uniswap Foundation - Atrium Academy

---

## 📚 Contenido de la Sesión

### 1. Introducción Técnica
### 2. Arquitectura v4  
### 3. Hooks v4

---

## 🏗️ Arquitectura v4

### Diseño Singleton

#### Diseño v3 (Problema a Resolver)

**Liquidez Concentrada en v3:**
- Uniswap V3 es un AMM de propósito general con liquidez concentrada
- Los LPs no están obligados a proporcionar liquidez en todo el rango de precios
- Permite mercados altamente eficientes en capital
- Para tokens no volátiles, la mayor parte de la liquidez existe alrededor de precios comunes

**Limitaciones de v3:**
- Cada pool era su propio contrato inteligente desplegado a través de `UniswapV3Factory`
- Acciones como crear un nuevo pool o hacer swaps multi-hop eran costosas
- Cada pool requería llamadas a funciones externas

**Arquitectura de Alto Nivel v3:**
```solidity
contract UniswapV3Factory {
    // Mapping: "Token X" -> "Token Y" -> "Tick Spacing" -> "Pool Contract Address"
    // e.g. USDC -> WETH -> 10 -> 0x0....
    mapping(address => mapping(address => mapping(uint24 => address))) public pools;
 
    function createPool(address tokenX, address tokenY, uint24 fee, ...) {
        // Verificaciones necesarias
        address pool = new UniswapV3Pool{salt: ...}(); // Despliegue CREATE2
        pools[tokenX][tokenY][tickSpacing] = pool;
    }
}
```

#### Diseño v4 (Solución)

**Concepto Clave:** Un solo contrato `PoolManager` gestiona todos los pools

**Cambios Fundamentales:**
- Los pools ahora se implementan como bibliotecas de Solidity
- Todos los pools viven dentro del contrato `PoolManager`
- No hay contratos separados para cada pool

**Implementación:**
```solidity
// Biblioteca Pool
library Pool {
    function initialize(State storage self, ...) {
        // ...
    }
 
    function swap(State storage self, ...) {
        // ...
    }
 
    function modifyPosition(State storage self, ...) {
        // ...
    }
}

// PoolManager
contract PoolManager {
    using Pools for *;
    mapping (PoolId id => Pool.State) internal pools;
 
    function swap(PoolId id, ...) {
        pools[id].swap(...); // Llamada a biblioteca
    }
}
```

**Diferencias Clave:**
- En v3: `pools mapping` → dirección del contrato
- En v4: `pools mapping` → struct `Pool.State`
- Toda la lógica AMM encapsulada dentro del `PoolManager`
- Sin llamadas a funciones externas requeridas

---

## ⚡ Flash Accounting & Locking

### Flash Accounting

**Problema en v3:**
- Cada swap (incluyendo multi-hop) requería transferir tokens fuera del contrato Pool
- Luego transferir a su destino (siguiente pool o usuario)
- Ineficiente, especialmente en swaps multi-hop
- Costoso debido a múltiples llamadas externas

**Solución en v4:**
- Los tokens se mueven al `PoolManager`
- Todas las acciones se realizan internamente
- Solo los tokens de salida finales necesitan ser retirados

**Ejemplo: ETH → DAI (via USDC)**

*Versiones anteriores:*
1. ETH → contrato pool ETH/USDC
2. USDC retirado → enviado a contrato pool USDC/DAI  
3. DAI retirado → enviado al usuario

*v4:*
1. ETH → PoolManager
2. PoolManager calcula cantidad de salida USDC
3. Sin transferir tokens, PoolManager calcula cantidad DAI para swap USDC → DAI
4. DAI retirado → enviado al usuario

**Beneficio:** Omite el paso de llamar `transfer()` en el contrato USDC

### Mecanismo de Locking

**Propósito:** Asegurar corrección y atomicidad en operaciones complejas

**Función unlock:**
```solidity
function unlock(bytes calldata data)
    external
    override
    noDelegateCall
    returns (bytes memory result) {
        if (Lock.isUnlocked()) revert AlreadyUnlocked();
 
        Lock.unlock();
 
        // El caller hace todo lo que necesita dentro de este callback
        result = IUnlockCallback(msg.sender).unlockCallback(data);
 
        if (NonZeroDeltaCount.read() != 0) revert CurrencyNotSettled();
        Lock.lock();
}
```

**Flujo de Trabajo:**
1. Contrato periférico llama `unlock`
2. Verifica que el PoolManager no esté ya desbloqueado
3. Desbloquea y llama `unlockCallback` en el contrato periférico
4. El contrato periférico ejecuta sus operaciones
5. Verifica que todos los balances estén liquidados
6. Bloquea nuevamente

**Balance Deltas:**
- Rastrea débitos y créditos de activos del PoolManager
- Comienza con pizarra limpia cuando se desbloquea
- Debe ser balance neto-cero al final para que la transacción sea exitosa

---

## 💾 Transient Storage

**EIP 1153:** Introduce opcodes `TSTORE` y `TLOAD`
- Nueva ubicación de almacenamiento de datos en la EVM
- Transitorio: existe solo en el contexto de una transacción
- Muy barato para leer/escribir

**Implementación en v4:**
```solidity
library Lock {
    // Slot que mantiene el estado desbloqueado, transitoriamente
    uint256 constant IS_UNLOCKED_SLOT = uint256(0xc090fc4683624cfc3884e9d8de5eca132f2d0ec062aff75d43c0465d5ceeab23);
 
    function unlock() internal {
        uint256 slot = IS_UNLOCKED_SLOT;
        assembly {
            tstore(slot, true)
        }
    }
 
    function isUnlocked() internal view returns (bool unlocked) {
        uint256 slot = IS_UNLOCKED_SLOT;
        assembly {
            unlocked := tload(slot)
        }
    }
}
```

**Dato Curioso:** Uniswap v4 se retrasó intencionalmente esperando que EIP-1153 se fusionara en mainnet

---

## 🎟️ ERC-6909 Claims

**Concepto:** Estándar de contrato multi-token simple
- Gestiona múltiples tokens ERC-20 desde un solo contrato inteligente
- Mejora el diseño de ERC-1155 simplificándolo

**Uso en v4:**
- Representa tokens de reclamo (claim tokens)
- Traders de alta frecuencia pueden dejar tokens en el PoolManager
- Reciben tokens ERC-6909 representando su reclamo
- En swaps futuros: quemar tokens de reclamo → acuñar nuevos tokens de reclamo

**Beneficios:**
- Evita llamadas a funciones externas
- Sin lógica personalizada de contratos externos (ej: lista negra de USDC)
- Overhead de gas constante independientemente del token subyacente

---

## 🪩 v4 Hooks

### Concepto

**Definición:** Contratos inteligentes que se pueden adjuntar a pools de liquidez para comportamiento personalizado

**Funciones de Hook Disponibles:**
- `beforeInitialize` / `afterInitialize`
- `beforeAddLiquidity` / `afterAddLiquidity`  
- `beforeRemoveLiquidity` / `afterRemoveLiquidity`
- `beforeSwap` / `afterSwap`
- `beforeDonate` / `afterDonate`
- `beforeSwapReturnDelta` / `afterSwapReturnDelta`
- `afterAddLiquidityReturnDelta` / `afterRemoveLiquidityReturnDelta`

**Tipos de Hooks:**
- **Initialize:** Antes/después de inicializar un nuevo pool
- **Liquidity:** Antes/después de modificar posiciones de liquidez
- **Swap:** Antes/después de realizar swaps
- **Donate:** Antes/después de donaciones (propinas directas a LPs)
- **ReturnDelta:** Hooks No-Op avanzados

### Hook Address Bitmap

**Problema:** ¿Cómo sabe el PoolManager qué funciones implementa un contrato hook?

**Solución:** Las direcciones de los hooks codifican qué funciones implementan

**Mecanismo:**
- Cada función hook corresponde a una "bandera" específica
- Las banderas representan bits específicos en la dirección del contrato hook
- El valor del bit (0 o 1) indica si esa función está implementada

**Ejemplo:**
Dirección: `0x0000000000000000000000000000000000000090`
En binario (últimos 8 bits): `1001 0000`

- 5to bit = 1 → `AFTER_DONATE` implementado
- 8vo bit = 1 → `BEFORE_SWAP` implementado

**Importante:** Requiere minería de direcciones para encontrar direcciones de despliegue apropiadas

---

## 🔄 Flujos de Transacción

### Flujo de Swap

1. **Usuario** → Contrato periférico (ej: SwapRouter)
2. **Contrato periférico** → `unlock()` en PoolManager
3. **PoolManager** → `unlockCallback()` en contrato periférico
4. **Dentro del callback:**
   - Contrato periférico → `swap()` en PoolManager
   - PoolManager verifica validez del pool
   - Verifica si `beforeSwap` necesita ejecutarse
   - Ejecuta `beforeSwap` si es necesario
   - Realiza el swap real
   - Cobra tarifas de protocolo y emite evento Swap
   - Verifica si `afterSwap` necesita ejecutarse
   - Ejecuta `afterSwap` si es necesario
   - Retorna `BalanceDelta`
5. **Contrato periférico** liquida balances
6. **PoolManager** verifica balances liquidados y se bloquea
7. **Transacción completa**

### BalanceDelta

**Definición:** Dos valores int (pueden ser negativos) representando `amount0` y `amount1`

**Perspectiva del Usuario:**
- Valor positivo: PoolManager debe dinero al usuario
- Valor negativo: Usuario debe dinero al PoolManager

**Liquidación:**
1. Transferencia real de tokens
2. Acuñar/quemar tokens ERC-6909

### Flujo de Modificación de Liquidez

Similar al flujo de swap, pero:
- Usa `modifyLiquidity()` en lugar de `swap()`
- Ejecuta hooks `beforeAddLiquidity`/`afterAddLiquidity` o `beforeRemoveLiquidity`/`afterRemoveLiquidity`
- Emite evento `ModifyLiquidity`

---

## ⚠️ Consideraciones y Preocupaciones

### Consideraciones de Gas

**Preocupación:** Los hooks pueden aumentar significativamente los costos de gas

**Contraargumentos:**
1. **Pools sin hooks:** Los tokens populares tendrán versiones sin hooks para acciones cotidianas
2. **Funcionalidad específica:** Los usuarios que interactúan con hooks personalizados buscan funcionalidad específica
3. **Ecosistema L2:** Apuesta en el futuro centrado en rollups de Ethereum

### Fragmentación de Liquidez

**Identificación Única de Pool (5 elementos):**
1. Token 0
2. Token 1  
3. Dirección del Hook
4. Espaciado de tick
5. Tarifas de swap

**Realidad:** Ya ocurre en v3, pero los solucionadores (como Uniswap X) mitigan este problema

### Licencia BSL

**Estado Actual:** Parcialmente bajo Business Source License (BSL)

**Aclaraciones:**
1. **Alcance limitado:** Solo ciertas partes de v4-core
2. **Periphery libre:** v4-periphery es completamente MIT Licensed
3. **Expiración:** BSL expira en 2025
4. **Propósito:** Prevenir forks de bajo esfuerzo durante desarrollo

---

## 🎯 Puntos Clave para Recordar

1. **Singleton Architecture:** Un solo PoolManager gestiona todos los pools
2. **Flash Accounting:** Tokens solo se transfieren al final de las transacciones
3. **Locking Mechanism:** Asegura atomicidad y correctitud
4. **Transient Storage:** EIP-1153 proporciona eficiencia de gas
5. **ERC-6909 Claims:** Reduce costos para traders de alta frecuencia
6. **Hook System:** Permite comportamiento personalizado de pools
7. **Address Bitmap:** Codifica funciones implementadas en direcciones de hooks

---

## 📋 Próximos Pasos

Esta sesión cubre los fundamentos arquitectónicos. Las próximas sesiones cubrirán:
- Implementación práctica de hooks
- Casos de uso específicos
- Desarrollo y despliegue
- Integración con el ecosistema

---

*Fuente: Uniswap Foundation - Atrium Academy | v4 Hook Incubator* 