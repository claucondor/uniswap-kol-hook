# KOL Referral System MVP

A complete referral system for Key Opinion Leaders (KOLs) integrated with Uniswap V4 on Base mainnet. Allows KOLs to register, get referral codes, and earn rewards based on Total Value Locked (TVL) generated through their referrals.

## System Architecture

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

## Deployed Contracts (Base Mainnet)

| Contract | Address | Description |
|----------|---------|-------------|
| **ReferralRegistry** | `0x9E895E8DA3fF34C7B73D9Ad94d9E562c2D4Dc01e` | KOL and user registration |
| **TVLLeaderboard** | `0xBf133a716f07FF6a9C93e60EF3781EA491390688` | Ranking and rewards system |
| **ReferralHook** | `0x65E6c7be675a3169F90Bb074F19f616772498500` | Uniswap V4 hook |
| **KOLTEST1** | `0x52bc5Caf2520c31a7669A7FAaD0F8E37aF53c5D3` | Test token (18 decimals) |
| **KOLTEST2** | `0xFe3Ad79f52CD53bf8e948A32936d7d5EB53f00a7` | Test token (18 decimals) |

### Uniswap V4 (Base)
| Contract | Address |
|----------|---------|
| **Pool Manager** | `0x498581fF718922c3f8e6A244956aF099B2652b2b` |
| **Position Manager** | `0x7C5f5A4bBd8fD63184577525326123B519429bDc` |

### Active Pool ID
- **KOLTEST1/KOLTEST2**: `0x1c580e16c547b863f9bf433ef6d6fe98a533f71d8882b2fb7eca0c3ad7d8e296`

## How to Test the System

### 1. Get Test Tokens

```bash
# Use the integrated faucet
curl -X POST "http://localhost:8080/api/faucet" \
  -H "Content-Type: application/json" \
  -d '{"walletAddress": "YOUR_WALLET_ADDRESS"}'
```

Or use the frontend "Faucet" section to get tokens automatically.

### 2. Register as KOL

```bash
# Register KOL
curl -X POST "http://localhost:8080/api/referral/kol/register" \
  -H "Content-Type: application/json" \
  -d '{
    "kolAddress": "YOUR_WALLET_ADDRESS",
    "referralCode": "MY_UNIQUE_CODE"
  }'
```

### 3. Register User with Referral

```bash
# Register user
curl -X POST "http://localhost:8080/api/referral/user/register" \
  -H "Content-Type: application/json" \
  -d '{
    "userAddress": "USER_WALLET_ADDRESS",
    "referralCode": "KOL_CODE"
  }'
```

### 4. Add Liquidity (Frontend)

1. Connect wallet in the frontend
2. Go to "Pools" → "Add Liquidity" section
3. Specify amounts of KOLTEST1 and KOLTEST2
4. Confirm transaction
5. See automatic leaderboard update

## Installation and Setup

### Backend

```bash
cd kol-referral-backend
npm install
cp .env.example .env
# Configure environment variables
npm run dev
```

**Required environment variables:**
```env
PORT=8080
PRIVATE_KEY=your_private_key
RPC_URL=https://mainnet.base.org
BASESCAN_API_KEY=your_api_key (optional)
```

### Frontend

```bash
cd kol-referral-frontend
npm install
cp .env.example .env
# Configure backend URL
npm run dev
```

**Environment variables:**
```env
VITE_API_URL=http://localhost:8080
```

### Smart Contracts

```bash
cd kol-referral-system
forge install
cp .env.example .env
# Configure keys for deployment
forge test
```

## Current Features

### Implemented

- **KOL registration** with unique codes
- **Automatic referral system**
- **Real-time TVL tracking**
- **Dynamic leaderboard** with rankings
- **Complete Uniswap V4 integration**
- **Token faucet** for testing
- **Complete frontend** with MetaMask
- **REST API backend** with real data

### TVL Calculation

Currently TVL is calculated at **token level**:
- **KOLTEST1**: 1 token = 1 TVL unit
- **KOLTEST2**: 1 token = 1 TVL unit
- **Total TVL** = Sum of both tokens

## Future Roadmap

### Phase 2: Oracle Integration
- Integration with **Chainlink** or **Pyth** for USD prices
- **Real dollar TVL** calculation
- Support for **multiple pools** and tokens

### Phase 3: Rewards System
- **Automatic rewards** distribution
- **Configurable epochs**
- **Different reward types** (tokens, NFTs, etc.)
- **Staking mechanism** for KOLs

### Phase 4: Analytics & Gamification
- **Advanced dashboard** with detailed metrics
- **Badge system** and achievements
- **Referral tree** visualization
- **Historical performance** tracking

## Security

- Locally audited contracts
- **Access control** with roles
- **Reentrancy protection** in hooks
- **Input validation** in all functions

## Testing

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
# With frontend and backend running
npm run test:e2e
```

## Additional Documentation

- [Smart Contracts README](./kol-referral-system/README.md)
- [Backend API README](./kol-referral-backend/README.md)
- [Frontend README](./kol-referral-frontend/README.md)

## Contributing

1. Fork the project
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

## License

This project is under the MIT license. See `LICENSE` for more details.

## Support

For technical support or questions:
- Create an [Issue](https://github.com/your-repo/issues)
- Documentation: [Wiki](https://github.com/your-repo/wiki)

---

**Note**: This is an MVP for demonstration. For production, complete smart contract auditing and extensive testing is recommended. 