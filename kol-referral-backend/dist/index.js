"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const hono_1 = require("hono");
const node_server_1 = require("@hono/node-server");
const cors_1 = require("hono/cors");
const secure_headers_1 = require("hono/secure-headers");
const logger_1 = require("hono/logger");
const http_exception_1 = require("hono/http-exception");
const config_1 = require("./config");
const blockchain_1 = require("./services/blockchain");
const faucet_1 = __importDefault(require("./routes/faucet"));
const referral_1 = __importDefault(require("./routes/referral"));
const leaderboard_1 = __importDefault(require("./routes/leaderboard"));
const pool_1 = __importDefault(require("./routes/pool"));
const liquidity_1 = __importDefault(require("./routes/liquidity"));
const app = new hono_1.Hono();
// --- Middleware ---
app.use('*', (0, logger_1.logger)());
app.use('*', (0, secure_headers_1.secureHeaders)());
app.use('*', (0, cors_1.cors)({
    origin: config_1.config.isDevelopment ? '*' : ['https://yourdomain.com'],
    allowMethods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowHeaders: ['Content-Type', 'Authorization'],
}));
// --- Initialize Services ---
let servicesInitialized = false;
try {
    (0, blockchain_1.initializeBlockchainServices)();
    servicesInitialized = true;
    console.log('✅ Blockchain services initialized successfully');
}
catch (error) {
    console.error('❌ Failed to initialize blockchain services:', error);
    if (config_1.config.isProduction) {
        console.error('🚨 Exiting in production due to service initialization failure');
        process.exit(1);
    }
}
// --- Root endpoint ---
app.get('/', (c) => {
    return c.json({
        name: 'KOL Referral Backend',
        version: '1.0.0',
        description: 'Blockchain-powered KOL referral system with Hono',
        endpoints: {
            health: '/api/health',
            faucet: '/api/faucet',
            referral: '/api/referral',
            leaderboard: '/api/leaderboard',
            pool: '/api/pool',
            liquidity: '/api/liquidity'
        },
        status: 'running',
        framework: 'Hono ⚡',
        blockchain: 'Base Network',
        services: {
            blockchain: servicesInitialized ? 'healthy' : 'failed'
        }
    });
});
// --- Health check ---
app.get('/api/health', (c) => {
    const healthStatus = {
        status: servicesInitialized ? 'healthy' : 'degraded',
        timestamp: new Date().toISOString(),
        services: {
            blockchain: servicesInitialized ? 'healthy' : 'failed',
            faucet: servicesInitialized ? 'available' : 'unavailable',
            referralRegistry: servicesInitialized ? 'available' : 'unavailable',
            leaderboard: servicesInitialized ? 'available' : 'unavailable',
            poolManager: servicesInitialized ? 'available' : 'unavailable',
            liquidityManager: servicesInitialized ? 'available' : 'unavailable'
        },
        framework: 'Hono',
        environment: config_1.config.nodeEnv,
        contracts: {
            koltest1: config_1.config.contracts.koltest1,
            koltest2: config_1.config.contracts.koltest2,
            referralRegistry: config_1.config.contracts.referralRegistry
        }
    };
    return c.json(healthStatus, servicesInitialized ? 200 : 503);
});
// --- Routes ---
app.route('/api/faucet', faucet_1.default);
app.route('/api/referral', referral_1.default);
app.route('/api/leaderboard', leaderboard_1.default);
app.route('/api/pool', pool_1.default);
app.route('/api/liquidity', liquidity_1.default);
// --- 404 handler ---
app.notFound((c) => {
    return c.json({
        error: 'Not found',
        message: `Route ${c.req.url} not found`,
        available_endpoints: [
            '/api/health',
            '/api/faucet',
            '/api/referral/kol/register',
            '/api/referral/user/register',
            '/api/leaderboard',
            '/api/pool',
            '/api/liquidity'
        ]
    }, 404);
});
// --- Error handler ---
app.onError((err, c) => {
    console.error('🚨 Unhandled error:', err);
    if (err instanceof http_exception_1.HTTPException) {
        return err.getResponse();
    }
    return c.json({
        error: 'Internal server error',
        message: config_1.config.isDevelopment ? err.message : 'Something went wrong',
        timestamp: new Date().toISOString()
    }, 500);
});
// --- Server startup ---
console.log('🚀 KOL Referral Backend starting...');
console.log(`📊 Environment: ${config_1.config.nodeEnv}`);
console.log(`⚡ Framework: Hono (High Performance)`);
console.log(`🔗 Network: Base (${config_1.config.rpcUrl.includes('testnet') ? 'Testnet' : 'Mainnet'})`);
console.log(`🏗️ Architecture: Modular (routes + services)`);
const server = (0, node_server_1.serve)({
    fetch: app.fetch,
    port: config_1.config.port,
});
console.log(`🌐 Server running on port ${config_1.config.port}`);
console.log(`🔗 Health check: http://localhost:${config_1.config.port}/api/health`);
console.log(`💰 Faucet endpoints: http://localhost:${config_1.config.port}/api/faucet`);
console.log(`👥 Referral endpoints: http://localhost:${config_1.config.port}/api/referral`);
console.log(`🏆 Leaderboard endpoints: http://localhost:${config_1.config.port}/api/leaderboard`);
console.log(`🏊 Pool endpoints: http://localhost:${config_1.config.port}/api/pool`);
console.log(`💧 Liquidity endpoints: http://localhost:${config_1.config.port}/api/liquidity`);
if (config_1.config.isDevelopment) {
    console.log(`📚 API Documentation: http://localhost:${config_1.config.port}/`);
    console.log('🔧 Development mode: Detailed logging enabled');
}
// --- Graceful shutdown ---
const gracefulShutdown = (signal) => {
    console.log(`🛑 ${signal} received, shutting down gracefully...`);
    // Close server
    console.log('📡 Closing HTTP server...');
    // Give time for pending requests to complete
    setTimeout(() => {
        console.log('✅ Graceful shutdown complete');
        process.exit(0);
    }, 1000);
};
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
// --- Unhandled rejections and exceptions ---
process.on('unhandledRejection', (reason, promise) => {
    console.error('🚨 Unhandled Rejection at:', promise, 'reason:', reason);
    if (config_1.config.isProduction) {
        gracefulShutdown('UNHANDLED_REJECTION');
    }
});
process.on('uncaughtException', (error) => {
    console.error('🚨 Uncaught Exception:', error);
    gracefulShutdown('UNCAUGHT_EXCEPTION');
});
exports.default = app;
