// Contract addresses on Base Mainnet
export const CONTRACTS = {
  // Core contracts
  REFERRAL_REGISTRY: '0x9E895E8DA3fF34C7B73D9Ad94d9E562c2D4Dc01e',
  TVL_LEADERBOARD: '0xBf133a716f07FF6a9C93e60EF3781EA491390688',
  REFERRAL_HOOK: '0x65E6c7be675a3169F90Bb074F19f616772498500',
  
  // Uniswap V4
  POOL_MANAGER: '0x498581fF718922c3f8e6A244956aF099B2652b2b',
  POSITION_MANAGER: '0x7C5f5A4bBd8fD63184577525326123B519429bDc', // Correct address from BaseScript.sol
  
  // Test tokens (UPDATED - NEW DEPLOYMENT)
  KOLTEST1: '0x52bc5Caf2520c31a7669A7FAaD0F8E37aF53c5D3',
  KOLTEST2: '0xFe3Ad79f52CD53bf8e948A32936d7d5EB53f00a7',
  
  // Uniswap V4 contracts
  HOOK_DEPLOYER: '0x4e59b44847b379578588920ca78FbF26c0B4956C',
} as const;

// Network configuration
export const NETWORK = {
  chainId: 8453, // Base mainnet
  name: 'Base',
  rpcUrl: 'https://mainnet.base.org',
  blockExplorer: 'https://basescan.org',
} as const;

// Backend API configuration
export const API_CONFIG = {
  baseUrl: import.meta.env.VITE_API_URL || 'http://localhost:8080',
  endpoints: {
    // System
    health: '/api/health',
    
    // Faucet
    faucet: '/api/faucet',
    faucetHealth: '/api/faucet/health',
    
    // Referral
    kolRegister: '/api/referral/kol/register',
    userRegister: '/api/referral/user/register',
    referralCode: '/api/referral/code',
    userReferral: '/api/referral/user',
    referralHealth: '/api/referral/health',
    
    // Leaderboard
    leaderboard: '/api/leaderboard',
    currentEpoch: '/api/leaderboard/epoch',
    epochLeaderboard: '/api/leaderboard/epoch',
    kolRanking: '/api/leaderboard/kol',
    leaderboardHealth: '/api/leaderboard/health',
    
    // Pool
    poolCreate: '/api/pool/create',
    poolInfo: '/api/pool',
    poolEstimateGas: '/api/pool/estimate-gas',
    poolSimulate: '/api/pool/simulate',
    poolHealth: '/api/pool/health',
    
    // Liquidity
    liquidityAdd: '/api/liquidity/add',
    liquidityRemove: '/api/liquidity/remove',
    userPositions: '/api/liquidity/user',
    liquidityEstimateGas: '/api/liquidity/estimate-gas',
    liquiditySimulate: '/api/liquidity/simulate',
    liquidityHealth: '/api/liquidity/health',
  },
} as const; 