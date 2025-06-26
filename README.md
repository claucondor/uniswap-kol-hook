# KOL Referral System MVP

Un sistema completo de referidos para Key Opinion Leaders (KOLs) integrado con Uniswap V4 en Base mainnet. Permite a los KOLs registrarse, obtener códigos de referidos, y ganar rewards por el Total Value Locked (TVL) generado a través de sus referidos.

## 🏗️ Arquitectura del Sistema

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Frontend     │────│     Backend     │────│   Blockchain    │
│   (React/TS)    │    │   (Node.js)     │    │ (Base Mainnet)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ├── ReferralRegistry
                                ├── TVLLeaderboard  
                                ├── ReferralHook
                                └── Test Tokens
```

## 🚀 Contratos Deployados (Base Mainnet)

| Contrato | Dirección | Descripción |
|----------|-----------|-------------|
| **ReferralRegistry** | `0x9E895E8DA3fF34C7B73D9Ad94d9E562c2D4Dc01e` | Registro de KOLs y usuarios |
| **TVLLeaderboard** | `0xBf133a716f07FF6a9C93e60EF3781EA491390688` | Sistema de ranking y rewards |
| **ReferralHook** | `0x65E6c7be675a3169F90Bb074F19f616772498500` | Hook de Uniswap V4 |
| **KOLTEST1** | `0x52bc5Caf2520c31a7669A7FAaD0F8E37aF53c5D3` | Token de prueba (18 decimales) |
| **KOLTEST2** | `0xFe3Ad79f52CD53bf8e948A32936d7d5EB53f00a7` | Token de prueba (18 decimales) |

### Uniswap V4 (Base)
| Contrato | Dirección |
|----------|-----------|
| **Pool Manager** | `0x498581fF718922c3f8e6A244956aF099B2652b2b` |
| **Position Manager** | `0x7C5f5A4bBd8fD63184577525326123B519429bDc` |

### Pool ID Activo
- **KOLTEST1/KOLTEST2**: `0x1c580e16c547b863f9bf433ef6d6fe98a533f71d8882b2fb7eca0c3ad7d8e296`

## 🔧 Cómo Probar el Sistema

### 1. Obtener Tokens de Prueba

```bash
# Usar el faucet integrado del sistema
curl -X POST "http://localhost:8080/api/faucet" \
  -H "Content-Type: application/json" \
  -d '{"walletAddress": "TU_WALLET_ADDRESS"}'
```

O usar el frontend en la sección "Faucet" para obtener tokens automáticamente.

### 2. Registrarse como KOL

```bash
# Registrar KOL
curl -X POST "http://localhost:8080/api/referral/kol/register" \
  -H "Content-Type: application/json" \
  -d '{
    "kolAddress": "TU_WALLET_ADDRESS",
    "referralCode": "MI_CODIGO_UNICO"
  }'
```

### 3. Registrar Usuario con Referido

```bash
# Registrar usuario
curl -X POST "http://localhost:8080/api/referral/user/register" \
  -H "Content-Type: application/json" \
  -d '{
    "userAddress": "WALLET_DEL_USUARIO",
    "referralCode": "CODIGO_DEL_KOL"
  }'
```

### 4. Agregar Liquidez (Frontend)

1. Conectar wallet en el frontend
2. Ir a la sección "Pools" → "Add Liquidity"
3. Especificar cantidades de KOLTEST1 y KOLTEST2
4. Confirmar transacción
5. Ver actualización automática en el leaderboard

## 🚀 Instalación y Ejecución

### Backend

```bash
cd kol-referral-backend
npm install
cp .env.example .env
# Configurar variables de entorno
npm run dev
```

**Variables de entorno requeridas:**
```env
PORT=8080
PRIVATE_KEY=tu_private_key
RPC_URL=https://mainnet.base.org
BASESCAN_API_KEY=tu_api_key (opcional)
```

### Frontend

```bash
cd kol-referral-frontend
npm install
cp .env.example .env
# Configurar URL del backend
npm run dev
```

**Variables de entorno:**
```env
VITE_API_URL=http://localhost:8080
```

### Smart Contracts

```bash
cd kol-referral-system
forge install
cp .env.example .env
# Configurar keys para deploy
forge test
```

## 📊 Funcionalidades Actuales

### ✅ Implementado

- **Registro de KOLs** con códigos únicos
- **Sistema de referidos** automático
- **Tracking de TVL** en tiempo real
- **Leaderboard dinámico** con rankings
- **Integración Uniswap V4** completa
- **Faucet de tokens** para testing
- **Frontend completo** con MetaMask
- **Backend API REST** con datos reales

### 🎯 Cálculo de TVL

Actualmente el TVL se calcula a **nivel de tokens**:
- **KOLTEST1**: 1 token = 1 unidad de TVL
- **KOLTEST2**: 1 token = 1 unidad de TVL
- **TVL Total** = Suma de ambos tokens

## 🔮 Roadmap Futuro

### Phase 2: Oracle Integration
- Integración con **Chainlink** o **Pyth** para precios USD
- Cálculo de TVL en **dólares reales**
- Soporte para **múltiples pools** y tokens

### Phase 3: Rewards System
- **Distribución automática** de rewards
- **Epochs** con duración configurable
- **Diferentes tipos de rewards** (tokens, NFTs, etc.)
- **Staking mechanism** para KOLs

### Phase 4: Analytics & Gamification
- **Dashboard avanzado** con métricas detalladas
- **Sistema de badges** y logros
- **Referral trees** visualization
- **Historical performance** tracking

## 🔐 Seguridad

- Contratos auditados localmente
- **Access control** con roles
- **Reentrancy protection** en hooks
- **Input validation** en todas las funciones

## 🧪 Testing

### Contracts
```bash
cd kol-referral-system
forge test -vvv
```

### Backend
```bash
cd kol-referral-backend
npm test
```

### E2E Testing
```bash
# Con frontend y backend corriendo
npm run test:e2e
```

## 📚 Documentación Adicional

- [Smart Contracts README](./kol-referral-system/README.md)
- [Backend API README](./kol-referral-backend/README.md)
- [Frontend README](./kol-referral-frontend/README.md)

## 🤝 Contribuir

1. Fork el proyecto
2. Crear feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a branch (`git push origin feature/AmazingFeature`)
5. Abrir Pull Request

## 📝 Licencia

Este proyecto está bajo la licencia MIT. Ver `LICENSE` para más detalles.

## 🆘 Soporte

Para soporte técnico o preguntas:
- Crear un [Issue](https://github.com/tu-repo/issues)
- Documentación: [Wiki](https://github.com/tu-repo/wiki)

---

**Nota**: Este es un MVP para demostración. Para producción se recomienda auditoría completa de smart contracts y testing extensivo. 