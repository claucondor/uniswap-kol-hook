"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.FAUCET_RATE_LIMIT_MAX_REQUESTS = exports.FAUCET_RATE_LIMIT_WINDOW_MS = exports.FAUCET_AMOUNT_KOLTEST2_STR = exports.FAUCET_AMOUNT_KOLTEST1_STR = exports.POOL_MANAGER_ADDRESS = exports.TVL_LEADERBOARD_ADDRESS = exports.REFERRAL_HOOK_V2_ADDRESS = exports.REFERRAL_REGISTRY_ADDRESS = exports.KOLTEST2_ADDRESS = exports.KOLTEST1_ADDRESS = exports.PORT = exports.BACKEND_WALLET_PRIVATE_KEY = exports.RPC_URL = exports.faucetRateLimiter = exports.config = void 0;
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
// Environment configuration
exports.config = {
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
    if (!exports.config.backendWalletPrivateKey) {
        throw new Error('BACKEND_WALLET_PRIVATE_KEY is required');
    }
    if (exports.config.port < 1 || exports.config.port > 65535) {
        throw new Error('PORT must be between 1 and 65535');
    }
    console.log('✅ Configuration validated successfully');
}
exports.faucetRateLimiter = new Map();
// Legacy exports for backward compatibility
exports.RPC_URL = exports.config.rpcUrl;
exports.BACKEND_WALLET_PRIVATE_KEY = exports.config.backendWalletPrivateKey;
exports.PORT = exports.config.port;
exports.KOLTEST1_ADDRESS = exports.config.contracts.koltest1;
exports.KOLTEST2_ADDRESS = exports.config.contracts.koltest2;
exports.REFERRAL_REGISTRY_ADDRESS = exports.config.contracts.referralRegistry;
exports.REFERRAL_HOOK_V2_ADDRESS = exports.config.contracts.referralHookV2;
exports.TVL_LEADERBOARD_ADDRESS = exports.config.contracts.tvlLeaderboard;
exports.POOL_MANAGER_ADDRESS = exports.config.contracts.poolManager;
exports.FAUCET_AMOUNT_KOLTEST1_STR = exports.config.faucet.amountKoltest1;
exports.FAUCET_AMOUNT_KOLTEST2_STR = exports.config.faucet.amountKoltest2;
exports.FAUCET_RATE_LIMIT_WINDOW_MS = exports.config.faucet.rateLimitWindowMs;
exports.FAUCET_RATE_LIMIT_MAX_REQUESTS = exports.config.faucet.rateLimitMaxRequests;
// Initialize and validate configuration
try {
    validateConfig();
    if (exports.config.isDevelopment) {
        console.log('🔧 Configuration loaded (Development):');
        console.log(`  📡 RPC URL: ${exports.config.rpcUrl.substring(0, 30)}...`);
        console.log(`  🪙 KOLTEST1: ${exports.config.contracts.koltest1}`);
        console.log(`  🪙 KOLTEST2: ${exports.config.contracts.koltest2}`);
        console.log(`  💰 Faucet Amounts: ${exports.config.faucet.amountKoltest1}/${exports.config.faucet.amountKoltest2}`);
        console.log(`  ⏱️  Rate Limit: ${exports.config.faucet.rateLimitMaxRequests} req/${exports.config.faucet.rateLimitWindowMs}ms`);
    }
    else {
        console.log('🚀 Production configuration loaded successfully');
    }
}
catch (error) {
    console.error('❌ Configuration validation failed:', error);
    process.exit(1);
}
