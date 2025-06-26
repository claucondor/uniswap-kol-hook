import { Hono } from 'hono';
import { serve } from '@hono/node-server';
import { cors } from 'hono/cors';
import { secureHeaders } from 'hono/secure-headers';
import { logger } from 'hono/logger';
import { HTTPException } from 'hono/http-exception';

import { config } from './config';
import { initializeBlockchainServices } from './services/blockchain';
import faucetRoutes from './routes/faucet';
import referralRoutes from './routes/referral';
import leaderboardRoutes from './routes/leaderboard';
import poolRoutes from './routes/pool';
import liquidityRoutes from './routes/liquidity';

const app = new Hono();

// --- Middleware ---
app.use('*', logger());
app.use('*', secureHeaders());
app.use('*', cors({
  origin: config.isDevelopment ? '*' : ['https://yourdomain.com'],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowHeaders: ['Content-Type', 'Authorization'],
}));

// --- Initialize Services ---
let servicesInitialized = false;
try {
  initializeBlockchainServices();
  servicesInitialized = true;
  console.log('✅ Blockchain services initialized successfully');
} catch (error) {
  console.error('❌ Failed to initialize blockchain services:', error);
  if (config.isProduction) {
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
    environment: config.nodeEnv,
    contracts: {
      koltest1: config.contracts.koltest1,
      koltest2: config.contracts.koltest2,
      referralRegistry: config.contracts.referralRegistry
    }
  };

  return c.json(healthStatus, servicesInitialized ? 200 : 503);
});

// --- Routes ---
app.route('/api/faucet', faucetRoutes);
app.route('/api/referral', referralRoutes);
app.route('/api/leaderboard', leaderboardRoutes);
app.route('/api/pool', poolRoutes);
app.route('/api/liquidity', liquidityRoutes);

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
  
  if (err instanceof HTTPException) {
    return err.getResponse();
  }
  
  return c.json({
    error: 'Internal server error',
    message: config.isDevelopment ? err.message : 'Something went wrong',
    timestamp: new Date().toISOString()
  }, 500);
});

// --- Server startup ---
console.log('🚀 KOL Referral Backend starting...');
console.log(`📊 Environment: ${config.nodeEnv}`);
console.log(`⚡ Framework: Hono (High Performance)`);
console.log(`🔗 Network: Base (${config.rpcUrl.includes('testnet') ? 'Testnet' : 'Mainnet'})`);
console.log(`🏗️ Architecture: Modular (routes + services)`);

const server = serve({
  fetch: app.fetch,
  port: config.port,
});

console.log(`🌐 Server running on port ${config.port}`);
console.log(`🔗 Health check: http://localhost:${config.port}/api/health`);
console.log(`💰 Faucet endpoints: http://localhost:${config.port}/api/faucet`);
console.log(`👥 Referral endpoints: http://localhost:${config.port}/api/referral`);
console.log(`🏆 Leaderboard endpoints: http://localhost:${config.port}/api/leaderboard`);
console.log(`🏊 Pool endpoints: http://localhost:${config.port}/api/pool`);
console.log(`💧 Liquidity endpoints: http://localhost:${config.port}/api/liquidity`);

if (config.isDevelopment) {
  console.log(`📚 API Documentation: http://localhost:${config.port}/`);
  console.log('🔧 Development mode: Detailed logging enabled');
}

// --- Graceful shutdown ---
const gracefulShutdown = (signal: string) => {
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
  if (config.isProduction) {
    gracefulShutdown('UNHANDLED_REJECTION');
  }
});

process.on('uncaughtException', (error) => {
  console.error('🚨 Uncaught Exception:', error);
  gracefulShutdown('UNCAUGHT_EXCEPTION');
});

export default app; 