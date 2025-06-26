import dotenv from 'dotenv';
dotenv.config();

// Environment configuration
export const config = {
  // Server configuration
  port: parseInt(process.env.PORT || '8080', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  isDevelopment: process.env.NODE_ENV !== 'production',
  isProduction: process.env.NODE_ENV === 'production',
  
  // Blockchain configuration
  rpcUrl: process.env.RPC_URL || 'https://mainnet.base.org',
  backendWalletPrivateKey: process.env.BACKEND_WALLET_PRIVATE_KEY,
  
  // Contract addresses (UPDATED - NEW DEPLOYMENT)
  contracts: {
    koltest1: process.env.KOLTEST1_ADDRESS || '0x52bc5Caf2520c31a7669A7FAaD0F8E37aF53c5D3',
    koltest2: process.env.KOLTEST2_ADDRESS || '0xFe3Ad79f52CD53bf8e948A32936d7d5EB53f00a7',
    referralRegistry: process.env.REFERRAL_REGISTRY_ADDRESS || '0x9E895E8DA3fF34C7B73D9Ad94d9E562c2D4Dc01e',
    referralHookV2: process.env.REFERRAL_HOOK_V2_ADDRESS || '0x65E6c7be675a3169F90Bb074F19f616772498500',
    tvlLeaderboard: process.env.TVL_LEADERBOARD_ADDRESS || '0xBf133a716f07FF6a9C93e60EF3781EA491390688',
    poolManager: process.env.POOL_MANAGER_ADDRESS || '0x498581fF718922c3f8e6A244956aF099B2652b2b',
    positionManager: process.env.POSITION_MANAGER_ADDRESS || '0x8fec0da0adb7aab466cfa9a463c87682ac7992ca'
  },
  
  // Test tokens for easy access
  testTokens: {
    KOLTEST1: process.env.KOLTEST1_ADDRESS || '0x52bc5Caf2520c31a7669A7FAaD0F8E37aF53c5D3',
    KOLTEST2: process.env.KOLTEST2_ADDRESS || '0xFe3Ad79f52CD53bf8e948A32936d7d5EB53f00a7'
  },
  
  // Faucet configuration
  faucet: {
    amountKoltest1: process.env.FAUCET_AMOUNT_KOLTEST1 || '100',
    amountKoltest2: process.env.FAUCET_AMOUNT_KOLTEST2 || '100',
    rateLimitWindowMs: 24 * 60 * 60 * 1000, // 24 hours
    rateLimitMaxRequests: 1 // 1 request per window
  }
};

// Validation function
function validateConfig() {
  if (!config.backendWalletPrivateKey) {
    throw new Error('BACKEND_WALLET_PRIVATE_KEY is required');
  }
  
  if (config.port < 1 || config.port > 65535) {
    throw new Error('PORT must be between 1 and 65535');
  }
  
  console.log('✅ Configuration validated successfully');
}

// Simple in-memory store for rate limiting (replace with Redis/etc. for production)
interface RateLimitEntry {
  timestamp: number;
  count: number;
}
export const faucetRateLimiter: Map<string, RateLimitEntry> = new Map();

// Legacy exports for backward compatibility
export const RPC_URL = config.rpcUrl;
export const BACKEND_WALLET_PRIVATE_KEY = config.backendWalletPrivateKey;
export const PORT = config.port;
export const KOLTEST1_ADDRESS = config.contracts.koltest1;
export const KOLTEST2_ADDRESS = config.contracts.koltest2;
export const REFERRAL_REGISTRY_ADDRESS = config.contracts.referralRegistry;
export const REFERRAL_HOOK_V2_ADDRESS = config.contracts.referralHookV2;
export const TVL_LEADERBOARD_ADDRESS = config.contracts.tvlLeaderboard;
export const POOL_MANAGER_ADDRESS = config.contracts.poolManager;
export const FAUCET_AMOUNT_KOLTEST1_STR = config.faucet.amountKoltest1;
export const FAUCET_AMOUNT_KOLTEST2_STR = config.faucet.amountKoltest2;
export const FAUCET_RATE_LIMIT_WINDOW_MS = config.faucet.rateLimitWindowMs;
export const FAUCET_RATE_LIMIT_MAX_REQUESTS = config.faucet.rateLimitMaxRequests;

// Initialize and validate configuration
try {
  validateConfig();
  
  if (config.isDevelopment) {
    console.log('🔧 Configuration loaded (Development):');
    console.log(`  📡 RPC URL: ${config.rpcUrl.substring(0,30)}...`);
    console.log(`  🪙 KOLTEST1: ${config.contracts.koltest1}`);
    console.log(`  🪙 KOLTEST2: ${config.contracts.koltest2}`);
    console.log(`  💰 Faucet Amounts: ${config.faucet.amountKoltest1}/${config.faucet.amountKoltest2}`);
    console.log(`  ⏱️  Rate Limit: ${config.faucet.rateLimitMaxRequests} req/${config.faucet.rateLimitWindowMs}ms`);
  } else {
    console.log('🚀 Production configuration loaded successfully');
  }
} catch (error) {
  console.error('❌ Configuration validation failed:', error);
  process.exit(1);
} 