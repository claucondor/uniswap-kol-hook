# KOL Referral System - Uniswap v4

Sistema de referidos gamificado para KOLs (Key Opinion Leaders) construido sobre Uniswap v4 en Base Mainnet.

## 🎯 Descripción

Sistema NFT que permite a KOLs obtener recompensas por generar TVL (Total Value Locked) en pools de Uniswap v4. Los KOLs reciben NFTs únicos con códigos de referral y ganan métricas basadas en la liquidez que sus referidos aportan.

## 📋 Contratos Desplegados

### Contratos Principales
- **ReferralRegistry**: `0x205C50E7888Fdb01E289B32DcB00152e41706Fb5`
- **TVLLeaderboard**: `0xa1375888DC41f791d4d52ffe536809Ac2C1C9116`  
- **ReferralHook**: `0x251369069A9c93A7615338c9a7127B9693428500`

### Tokens de Prueba
- **KOL Token**: `0xFAd83621dd9f7564Ab9497E50A6A9ce241061680`
- **Test USDC**: `0x8FeC0dA0Adb7Aab466cFa9a463c87682AC7992Ca`

### Pool Uniswap v4
- **Pool ID**: `0xe9c154b64b0560cb868bad7df2891ae5036ead142ce91b2025bc16c70984791b`
- **Par**: KOL/USDC (1% fee)
- **PoolManager**: `0x498581fF718922c3f8e6A244956aF099B2652b2b`

## 🚀 Cómo Funciona

1. **KOL minta NFT**: `referralRegistry.mint("mi-codigo")`
2. **KOL comparte código**: Los usuarios usan su código de referral
3. **Usuario registra referral**: `referralHook.setReferral("mi-codigo")`
4. **Usuario agrega liquidez**: El hook rastrea automáticamente el TVL
5. **KOL gana métricas**: TVL acumulado, usuarios únicos, rankings

## 🛠 Tecnologías

- **Solidity 0.8.26**
- **Foundry** (compilación y deployment)
- **Uniswap v4** (hooks y pools)
- **OpenZeppelin** (NFTs y access control)
- **Base Mainnet**

## 📊 Métricas Rastreadas

- Total TVL generado
- Usuarios únicos referidos
- Retention score (liquidez que permanece)
- Consistency score (estabilidad del TVL)
- Rankings mensuales (épocas de 30 días)

## 🔧 Scripts Disponibles

### Foundry Scripts
```bash
# Crear pool con hook
forge script script/CreatePoolAndAddLiquidity.s.sol --broadcast --rpc-url https://mainnet.base.org

# Verificar estado del pool
forge script script/TestPoolCreation.s.sol --rpc-url https://mainnet.base.org

# Desplegar tokens de prueba
forge script script/DeployTestTokens.s.sol --broadcast --rpc-url https://mainnet.base.org
```

### Compilación
```bash
forge build
forge test
```

## 🌐 Verificación en Basescan

Todos los contratos están verificados y son públicamente auditables:
- [ReferralRegistry](https://basescan.org/address/0x205C50E7888Fdb01E289B32DcB00152e41706Fb5)
- [TVLLeaderboard](https://basescan.org/address/0xa1375888DC41f791d4d52ffe536809Ac2C1C9116)
- [ReferralHook](https://basescan.org/address/0x251369069A9c93A7615338c9a7127B9693428500)

## 📁 Estructura del Proyecto

```
contracts/
├── core/           # ReferralRegistry (sistema NFT)
├── hooks/          # ReferralHook (integración Uniswap v4)
├── periphery/      # TVLLeaderboard (métricas y rankings)
├── interfaces/     # Interfaces de contratos
└── libraries/      # Utilidades (HookMiner, Create2Factory)

script/
├── base/           # Scripts base y helpers
├── Deploy*.s.sol   # Scripts de deployment
└── Test*.s.sol     # Scripts de testing
```

## 🎮 Uso del Sistema

### Para KOLs
```solidity
// 1. Mintear NFT referral
referralRegistry.mint("mi-codigo-unico");

// 2. Compartir código con audiencia
// Los usuarios usarán: "mi-codigo-unico"
```

### Para Usuarios
```solidity
// 1. Registrar referral del KOL
referralHook.setReferral("codigo-del-kol");

// 2. Agregar liquidez normalmente
// El hook rastrea automáticamente
```

## 🏆 Sistema de Recompensas

- Rankings cada 30 días por TVL promedio
- Bonificaciones por retention y consistency
- NFTs evolutivos basados en performance
- Métricas públicas y transparentes

## ⚡ Estado Actual

- ✅ Todos los contratos desplegados y verificados
- ✅ Pool Uniswap v4 creado e inicializado
- ✅ Sistema de hooks funcionando
- ⚠️ Listo para agregar liquidez inicial

## 🔮 Próximos Pasos

1. Agregar liquidez inicial al pool
2. Desarrollar frontend para usuarios
3. Integrar con routers de Uniswap v4
4. Expandir a más pools y tokens
5. Implementar distribución de recompensas

## 📄 Licencia

MIT
