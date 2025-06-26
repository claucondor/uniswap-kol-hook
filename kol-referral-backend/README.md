# Backend API - KOL Referral System

REST API for the KOL referral system with real-time integration to Base mainnet smart contracts.

## Features

- **Real-time blockchain integration** with Base mainnet
- **KOL and user registration** via smart contracts
- **Dynamic leaderboard** with live TVL data
- **Integrated token faucet** for testing
- **CORS configuration** for frontend integration
- **Error handling** and input validation
- **Automatic balance verification** before transactions

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Frontend     │────│   Backend API   │────│   Base Mainnet  │
│   (Port 3000)   │    │   (Port 8080)   │    │   (Contracts)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         └── HTTP Requests ──────┼── ethers.js ─────────┘
                                 │
                                 └── Contract ABIs
```

## 📋 API Endpoints

### 🔗 Base URL
```
http://localhost:8080/api
```

### 🚰 Faucet

#### Get Test Tokens
```http
POST /faucet
Content-Type: application/json

{
  "walletAddress": "0x1234567890123456789012345678901234567890"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Tokens sent successfully",
  "transactions": {
    "KOLTEST1": "0xabcd...",
    "KOLTEST2": "0xefgh..."
  }
}
```

### 👤 KOL Management

#### Register KOL
```http
POST /referral/kol/register
Content-Type: application/json

{
  "kolAddress": "0x1234567890123456789012345678901234567890",
  "referralCode": "MYSUPERCODE123"
}
```

**Response:**
```json
{
  "success": true,
  "message": "KOL registered successfully",
  "transactionHash": "0xabcd...",
  "referralCode": "MYSUPERCODE123"
}
```

#### Get KOL Statistics
```http
GET /referral/kol/stats/{kolAddress}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "kolAddress": "0x1234...",
    "totalTVL": "200000000000000000000000000",
    "referredUsers": 1,
    "rank": 1
  }
}
```

### 👥 User Management

#### Register User with Referral
```http
POST /referral/user/register
Content-Type: application/json

{
  "userAddress": "0x9876543210987654321098765432109876543210",
  "referralCode": "MYSUPERCODE123"
}
```

**Response:**
```json
{
  "success": true,
  "message": "User registered with referral",
  "transactionHash": "0xefgh...",
  "referrerAddress": "0x1234..."
}
```

#### Check User Referral Status
```http
GET /referral/user/status/{userAddress}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "isReferred": true,
    "referrerAddress": "0x1234...",
    "referralCode": "MYSUPERCODE123"
  }
}
```

### 🏆 Leaderboard

#### Get Top KOLs
```http
GET /leaderboard/top?limit=10&offset=0
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "address": "0x1234...",
      "totalTVL": "200000000000000000000000000",
      "referredUsers": 1,
      "rank": 1
    }
  ],
  "total": 1,
  "limit": 10,
  "offset": 0
}
```

#### Get Complete Leaderboard
```http
GET /leaderboard/full
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "address": "0x1234...",
      "totalTVL": "200000000000000000000000000",
      "referredUsers": 1,
      "rank": 1
    }
  ],
  "lastUpdated": "2024-01-20T10:30:00Z"
}
```

### ⚡ System Health

#### Health Check
```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-20T10:30:00Z",
  "blockchain": {
    "connected": true,
    "network": "base-mainnet",
    "blockNumber": 12345678
  }
}
```

## 🔧 Installation and Setup

### 1. Environment Setup

```bash
# Clone the repository
cd kol-referral-backend

# Install dependencies
npm install

# Copy environment configuration
cp .env.example .env
```

### 2. Environment Variables

```env
# Server Configuration
PORT=8080
NODE_ENV=development

# Blockchain Configuration
PRIVATE_KEY=your_private_key_here
RPC_URL=https://mainnet.base.org

# Contract Addresses (Base Mainnet)
REFERRAL_REGISTRY_ADDRESS=0x9E895E8DA3fF34C7B73D9Ad94d9E562c2D4Dc01e
TVL_LEADERBOARD_ADDRESS=0xBf133a716f07FF6a9C93e60EF3781EA491390688
REFERRAL_HOOK_ADDRESS=0x65E6c7be675a3169F90Bb074F19f616772498500
KOLTEST1_ADDRESS=0x52bc5Caf2520c31a7669A7FAaD0F8E37aF53c5D3
KOLTEST2_ADDRESS=0xFe3Ad79f52CD53bf8e948A32936d7d5EB53f00a7

# Optional
BASESCAN_API_KEY=your_basescan_api_key
```

### 3. Start Development Server

```bash
# Development mode with hot reload
npm run dev

# Production mode
npm start

# Production with PM2
npm run start:prod
```

The server will start at `http://localhost:8080`

## 🧪 Testing

### Unit Tests
```bash
# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Run specific test file
npm test -- faucet.test.js
```

### Integration Tests
```bash
# Test with real blockchain (requires .env)
npm run test:integration

# Test specific endpoints
npm run test:api
```

### Manual Testing with cURL

```bash
# Test faucet
curl -X POST "http://localhost:8080/api/faucet" \
  -H "Content-Type: application/json" \
  -d '{"walletAddress": "0x..."}'

# Test KOL registration
curl -X POST "http://localhost:8080/api/referral/kol/register" \
  -H "Content-Type: application/json" \
  -d '{"kolAddress": "0x...", "referralCode": "TEST123"}'

# Test leaderboard
curl "http://localhost:8080/api/leaderboard/top"
```

## 📊 Current Architecture

### Service Layer

```
src/
├── routes/
│   ├── faucet.js           # Token distribution
│   ├── referral.js         # KOL/User management
│   ├── leaderboard.js      # Rankings
│   └── health.js           # System status
├── services/
│   ├── blockchainService.js # Smart contract interactions
│   ├── faucetService.js     # Token distribution logic
│   ├── referralService.js   # Registration logic
│   └── leaderboardService.js # Rankings calculation
├── contracts/
│   ├── abi/                 # Contract ABIs
│   └── addresses.js         # Contract addresses
└── utils/
    ├── validation.js        # Input validation
    └── errors.js           # Error handling
```

### Blockchain Integration

```javascript
// Example: Getting real TVL data
const leaderboardContract = new ethers.Contract(
  LEADERBOARD_ADDRESS,
  LeaderboardABI,
  provider
);

const getKOLStats = async (kolAddress) => {
  const stats = await leaderboardContract.getKOLStats(kolAddress);
  return {
    totalTVL: stats[0].toString(),
    referredUsers: stats[1].toNumber()
  };
};
```

## 🔄 Current Data Flow

### 1. KOL Registration
```
Frontend → Backend API → ReferralRegistry Contract → Blockchain
                                    ↓
Backend ← Blockchain ← Transaction Confirmation
```

### 2. Leaderboard Updates
```
User adds liquidity → Uniswap V4 Hook → TVLLeaderboard Contract
                                              ↓
Backend API calls ← getKOLStats() ← Smart Contract
                                              ↓
Frontend receives ← Real-time data ← Backend response
```

### 3. Faucet System
```
Frontend request → Backend API → KOLTEST1/KOLTEST2 Contracts
                                        ↓
User wallet ← Tokens transferred ← Contract execution
```

## 🔮 Future Features (Roadmap)

### Phase 2: Advanced API
- **WebSocket integration** for real-time updates
- **Pagination** optimization for large datasets
- **Caching layer** with Redis
- **Rate limiting** per wallet address

### Phase 3: Analytics API
- **Historical data** endpoints
- **TVL trends** analytics
- **Performance metrics** per KOL
- **Referral conversion** tracking

### Phase 4: Advanced Features
- **Multi-chain support** (Polygon, Arbitrum)
- **Notification system** for events
- **Automated reward** distribution
- **Advanced filtering** and search

## 🔐 Security

### Input Validation
```javascript
// Example validation
const validateAddress = (address) => {
  if (!ethers.isAddress(address)) {
    throw new Error('Invalid Ethereum address');
  }
};

const validateReferralCode = (code) => {
  if (!/^[A-Z0-9]{3,20}$/.test(code)) {
    throw new Error('Invalid referral code format');
  }
};
```

### Error Handling
```javascript
// Standardized error responses
app.use((error, req, res, next) => {
  const response = {
    success: false,
    message: error.message,
    code: error.code || 'INTERNAL_ERROR'
  };
  
  res.status(error.status || 500).json(response);
});
```

### Access Control
- **Private key** security for contract interactions
- **CORS** configuration for frontend access
- **Rate limiting** (planned)
- **Input sanitization** for all endpoints

## 📈 Performance

### Current Metrics
- **Response time**: < 200ms for cached data
- **Blockchain calls**: ~2-3 seconds for contract interactions
- **Faucet distribution**: ~5-10 seconds per transaction
- **Leaderboard updates**: Real-time via contract calls

### Optimization
- **Contract call batching** for multiple queries
- **Response caching** for static data
- **Connection pooling** for blockchain provider
- **Async processing** for heavy operations

## 🐛 Common Issues and Solutions

### Issue: "Transaction Failed"
**Solution**: Check that the wallet has enough ETH for gas fees

### Issue: "Contract Call Failed"
**Solution**: Verify contract addresses in `.env` file

### Issue: "Faucet Empty"
**Solution**: The faucet has a daily limit, try again later

### Issue: "RPC Rate Limit"
**Solution**: Add API key for your RPC provider

## 🤝 Contributing

### Code Standards
- ESLint configuration for consistent style
- Comprehensive test coverage required
- JSDoc comments for all functions
- Error handling for all async operations

### Development Workflow
```bash
# Create feature branch
git checkout -b feature/new-endpoint

# Make changes and test
npm test
npm run lint

# Commit and push
git commit -m "Add new endpoint for X"
git push origin feature/new-endpoint
```

## 📝 License

MIT License - see LICENSE file for details.

---

**Note**: This backend connects to real smart contracts on Base mainnet. For production use, implement additional security measures and monitoring. 