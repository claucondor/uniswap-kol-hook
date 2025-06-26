# Sesión 2: Ticks y Números Q64.96
## Uniswap Foundation - Atrium Academy

---

## 🎯 Objetivos de la Lección

Al finalizar esta sesión, podrás:

- ✅ **Entender qué son los "ticks"** y qué significan
- ✅ **Comprender curvas de precios continuas vs. discretas**
- ✅ **Convertir entre valores de tick y precio actual** de un token (relativo a otro token)
- ✅ **Convertir números hacia y desde su Notación Q**
- ✅ **Calcular valores sqrtPriceX96** en ticks dados
- ✅ **Entender dónde se usan estos cálculos** y por qué los desarrolladores de hooks deben preocuparse

---

## 📚 Contenido de la Sesión

### 1. Ticks
### 2. Números Q64.96
### 3. Ejemplos Prácticos

---

## 🎯 Ticks

### Curvas de Precios Discretas

#### Uniswap v2: Curva Continua Infinita

**Características:**
- Implementación CFMM simple con la ecuación `xy = k`
- LPs obligados a proporcionar liquidez "rango completo"
- `k` es constante → ni `x` ni `y` pueden llegar a cero
- Curva infinita y continua que nunca toca los ejes

```
x * y = k
```

**Visualización:**
```
    y
    |
    |    ∞
    |   /
    |  /
    | /
    |/_________ x
           ∞
```

#### Uniswap v3: Curva Finita Discreta

**Cambio Fundamental:**
- Introducción de liquidez concentrada
- LPs eligen "rango de precio" específico
- Curvas finitas que SÍ tocan los ejes
- Permite división en secciones finitas

**Visualización:**
```
    y
    |
    |\
    | \
    |  \
    |   \
    |____\__ x
```

### Distribución de Liquidez

#### Uniswap v2: Distribución Plana
```
Liquidez
    |
████████████████████████████████
    |_________________________ Precio
```
*Liquidez uniforme en toda la curva*

#### Uniswap v3: Distribución Concentrada
```
Liquidez
    |        ██
    |      ██████
    |    ██████████
    |  ████████████████
    |██████████████████████
    |_________________________ Precio
              ↑
         Precio Actual
```
*Liquidez concentrada alrededor del precio actual*

### Definición de Ticks

**¿Qué es un Tick?**
- Un punto específico en la curva donde puede ocurrir un intercambio
- Cada tick representa un precio específico para el token
- Los ticks están espaciados uniformemente
- Son números enteros

**Ejemplo Visual:**
```
Ticks:  -9  -8  -7  -6  -5  -4  -3  -2  -1   0  +1  +2  +3  +4  +5  +6  +7  +8  +9
        |---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
                                                  ↑
                                            Precio Actual
```

### Insights Clave

#### 🔍 **Insight #1**
> Los ticks dividen la curva de precios finita continua en una curva con puntos discretos espaciados uniformemente. Cada punto discreto representa un precio específico al cual pueden ocurrir intercambios.

#### 🔍 **Insight #2**  
> La brecha entre dos ticks adyacentes - llamada tick spacing - es el movimiento de precio relativo más pequeño posible para un par dado de activos en un pool.

### Movimiento de Ticks

**Ejemplo Práctico:**
```
Antes del Swap:    Tick = 1
Después del Swap:  Tick = 4.5 → Se redondea a Tick = 4 o 5
```

**Características:**
- Los intercambios solo pueden ocurrir en valores de tick enteros
- Si el cálculo resulta en un valor fraccionario, se redondea al tick más cercano
- La pérdida de precisión es mínima debido a los millones de ticks disponibles

---

## 💰 Ticks ↔ Precios

### Fórmula Fundamental

```
p(i) = 1.0001^i

Donde:
- p(i) = precio relativo en el tick i
- i = valor del tick
- 1.0001 = base (representa 0.01% o 1 basis point)
```

### Token 0 y Token 1

**Determinación:**
- Los ticks siempre representan precios basados en Token 0 relativo a Token 1
- Sorting lexicográfico por direcciones de contrato
- Los tokens nativos (ETH) siempre son Token 0 (dirección zero)

**Ejemplo:**
```
Token A: 0x0000...  →  Token 0
Token B: 0x1234...  →  Token 1

Precio del tick = "Cuánto Token 1 por 1 unidad de Token 0"
```

### Ejemplos de Cálculo

#### Tick = 0
```solidity
p(i) = 1.0001^0 = 1

Resultado: 1 Token A = 1 Token B
```

#### Tick = 10 (Positivo)
```solidity
p(i) = 1.0001^10 = 1.0010004501

Resultado: 1 Token A = 1.0010004501 Token B
```
*Token A vale más que Token B por unidad*

#### Tick = -10 (Negativo)
```solidity
p(i) = 1.0001^(-10) = 0.99900054978

Resultado: 1 Token A = 0.99900054978 Token B
```
*Token B vale más que Token A por unidad*

### ¿Por qué 1.0001?

**Razón:** Cada tick representa un movimiento de **0.01%**

```
0.01% = 1 basis point (bps)
```

**Beneficios:**
- Excelente para análisis financiero
- Mantiene buena precisión
- Fácil de entender para traders

### Límites de Ticks

**Tipo de Datos:** `int24`
- Rango teórico: [-8,388,608, 8,388,607]
- Rango real enforced: **[-887,272, 887,272]**

---

## 🔢 Números Q64.96

### ¿Por qué necesitamos Q64.96?

**Problema:** Los ticks no son suficientes para todos los cálculos

**Ejemplo de Cálculo Complejo:**
> Un usuario tiene 2 ETH. Quiere crear una posición de liquidez en un pool ETH/USDC. El precio actual de ETH es 2000 USDC. Quiere agregar liquidez en el rango de 1500 a 2500 USDC. ¿Cuánto USDC necesita?

**Fórmulas Requeridas:**
```
Δy = L * (1/√P_a - 1/√P_b)

Donde:
- L = liquidez
- √P_a = raíz cuadrada del precio inferior
- √P_b = raíz cuadrada del precio superior
```

**Problema en Solidity:**
- Solo maneja enteros
- No soporta números de punto flotante
- Pérdida significativa de precisión

### ¿Qué son los números Q64.96?

**Definición:**
- Representación de números racionales
- **64 bits** para la parte entera
- **96 bits** para la parte fraccionaria

**Fórmula de Conversión:**
```
Q_n = D_n * (2^96)

Donde:
- Q_n = número en notación Q64.96
- D_n = número en notación decimal
- k = 96 (bits fraccionarios)
```

### Ejemplos de Conversión

#### Número 1
```
Decimal: 1
Q64.96: 1 * (2^96) = 2^96 = 79,228,162,514,264,337,593,543,950,336
```

#### Número 1.000234
```
Decimal: 1.000234
Q64.96: 1.000234 * 2^96 = 79,246,701,904,292,675,448,540,839,620.378624

Almacenado en Solidity: 79,246,701,904,292,675,448,540,839,620
```

### Ventajas de Q64.96

✅ **Precisión:** Mantiene precisión fraccionaria
✅ **Compatibilidad:** Funciona con enteros de Solidity  
✅ **Estándar:** Usado en todo el codebase de Uniswap
✅ **Eficiencia:** Cálculos optimizados para la EVM

### Implementación en el Código

**Referencia:** `TickMath.sol`
```solidity
// Funciones principales:
function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160)
function getTickAtSqrtRatio(uint160 sqrtPriceX96) internal pure returns (int24)
```

**Enlace:** [TickMath.sol](https://github.com/Uniswap/v4-core/blob/main/src/libraries/TickMath.sol)

---

## 🛠️ Ejemplos Prácticos

### Ejemplo 1: Hook de Orderbook On-chain

**Escenario:** Construyendo un orderbook como hook

**Inputs del Usuario:**
1. **Precio objetivo:** 1 ETH = 4000 USDC
2. **Slippage máximo:** 1.5%

**Proceso de Conversión:**

#### Paso 1: Precio → Tick
```solidity
// Usuario proporciona precio P
// Convertir a tick usando: i = log(P) / log(1.0001)
```

#### Paso 2: Slippage → sqrtPriceLimitX96
```solidity
struct SwapParams {
    int24 tickSpacing;
    bool zeroForOne;
    int256 amountSpecified;
    uint160 sqrtPriceLimitX96;  // ← Aquí necesitamos Q64.96
}
```

**Flujo de Swap:**
1. Se inicia el swap
2. Contrato conoce √P en el tick actual
3. Calcula cantidad de tokens de salida
4. Después del swap tiene nuevo valor √P
5. Compara nuevo √P contra `sqrtPriceLimitX96`
6. Si excede el límite → transacción falla

### Ejemplo 2: Hook de Rebalanceo de Posiciones

**Objetivo:** Rebalancear automáticamente posiciones LP para maximizar fees

**Preguntas a Responder:**
```
1. ¿Cuánta liquidez está disponible en un rango de precios dado?
2. ¿Cuánto de token Y se necesita para una cantidad dada de token X?
```

**Cálculos Necesarios:**
- Conversiones entre ticks, precios y números Q64.96
- Cálculos de liquidez usando fórmulas matemáticas complejas
- Optimización continua basada en condiciones del mercado

---

## 🔄 Proceso de Conversión Completo

### Flujo de Datos Típico

```
Usuario Input (Precio Decimal)
          ↓
    Conversión a Tick
          ↓
    Cálculos Internos
          ↓
    Conversión a Q64.96
          ↓
    Parámetros de Swap
          ↓
    Ejecución en PoolManager
```

### Herramientas de Conversión

**Funciones Principales:**
```solidity
// Tick ↔ √Price conversions
getSqrtRatioAtTick(int24 tick) → uint160 sqrtPriceX96
getTickAtSqrtRatio(uint160 sqrtPriceX96) → int24 tick

// Price calculations
price = (sqrtPriceX96 / 2^96)^2
sqrtPrice = sqrt(price) * 2^96
```

---

## 🎯 Puntos Clave para Recordar

1. **📊 Ticks = Puntos Discretos:** Representan precios específicos donde pueden ocurrir intercambios
2. **📏 Tick Spacing:** Determina el movimiento de precio mínimo posible
3. **🔢 Fórmula Base:** `p(i) = 1.0001^i` donde cada tick = 1 basis point
4. **🏷️ Token 0 vs Token 1:** Sorting lexicográfico determina la dirección del precio
5. **💾 Q64.96:** Notación necesaria para cálculos precisos en Solidity
6. **⚡ Conversión:** `Q_n = D_n * (2^96)` para convertir decimal a Q64.96
7. **🔧 Uso Práctico:** Esencial para hooks que manejan precios y slippage

---

## 🚀 Aplicaciones para Desarrolladores de Hooks

### Casos de Uso Comunes

✅ **Limit Orders:** Conversión de precios objetivo a ticks
✅ **Slippage Protection:** Cálculo de `sqrtPriceLimitX96`
✅ **Rebalancing:** Optimización de rangos de liquidez
✅ **Price Feeds:** Integración con oráculos externos
✅ **Dynamic Fees:** Ajuste de fees basado en volatilidad de precios

### Consideraciones de Implementación

⚠️ **Precisión:** Siempre usar Q64.96 para cálculos críticos
⚠️ **Rounding:** Ser consistente con el redondeo de ticks
⚠️ **Límites:** Verificar que los ticks estén dentro del rango válido
⚠️ **Gas:** Los cálculos complejos pueden ser costosos

---

## 📋 Próximos Pasos

Esta sesión cubre los fundamentos matemáticos. Las próximas sesiones cubrirán:
- Implementación práctica de cálculos de precio
- Construcción de hooks que usan ticks y Q64.96
- Casos de uso avanzados y optimizaciones
- Integración con herramientas de desarrollo

---

## 🔗 Referencias

- **Código Fuente:** [TickMath.sol](https://github.com/Uniswap/v4-core/blob/main/src/libraries/TickMath.sol)
- **Paper Técnico:** Liquidity Math in Uniswap V3
- **Documentación:** Uniswap v4 Developer Docs

---

*Fuente: Uniswap Foundation - Atrium Academy | v4 Hook Incubator* 