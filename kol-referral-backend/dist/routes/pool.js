"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const hono_1 = require("hono");
const http_exception_1 = require("hono/http-exception");
const ethers_1 = require("ethers");
const poolService_1 = require("../services/poolService");
const pool = new hono_1.Hono();
// Create pool with hook
pool.post('/create', async (c) => {
    try {
        const body = await c.req.json();
        const { token0, token1, fee, tickSpacing, hookAddress, initialPriceX96, userAddress } = body;
        // Validation
        if (!token0 || !ethers_1.ethers.isAddress(token0)) {
            return c.json({ success: false, message: 'Valid token0 address is required.' }, 400);
        }
        if (!token1 || !ethers_1.ethers.isAddress(token1)) {
            return c.json({ success: false, message: 'Valid token1 address is required.' }, 400);
        }
        if (!hookAddress || !ethers_1.ethers.isAddress(hookAddress)) {
            return c.json({ success: false, message: 'Valid hook address is required.' }, 400);
        }
        if (!userAddress || !ethers_1.ethers.isAddress(userAddress)) {
            return c.json({ success: false, message: 'Valid user address is required.' }, 400);
        }
        if (!fee || fee <= 0) {
            return c.json({ success: false, message: 'Valid fee is required.' }, 400);
        }
        if (!tickSpacing || tickSpacing <= 0) {
            return c.json({ success: false, message: 'Valid tick spacing is required.' }, 400);
        }
        console.log(`Creating pool: ${token0}/${token1} with hook ${hookAddress}`);
        const result = await (0, poolService_1.createPool)({
            token0,
            token1,
            fee,
            tickSpacing,
            hookAddress,
            initialPriceX96: initialPriceX96 || '79228162514264337593543950336', // 1:1 price
            userAddress
        });
        if (!result.success) {
            return c.json(result, 400);
        }
        return c.json(result, 201);
    }
    catch (error) {
        console.error('Error in POST /api/pool/create:', error);
        if (error instanceof SyntaxError) {
            return c.json({ success: false, message: 'Invalid JSON payload.' }, 400);
        }
        throw new http_exception_1.HTTPException(500, { message: 'Internal Server Error while creating pool.' });
    }
});
// Get pool info
pool.get('/:poolId/info', async (c) => {
    try {
        const poolId = c.req.param('poolId');
        if (!poolId) {
            return c.json({ success: false, message: 'Pool ID is required.' }, 400);
        }
        console.log(`Getting pool info for: ${poolId}`);
        const result = await (0, poolService_1.getPoolInfo)(poolId);
        if (!result.success) {
            return c.json(result, 404);
        }
        return c.json(result, 200);
    }
    catch (error) {
        console.error('Error in GET /api/pool/:poolId/info:', error);
        throw new http_exception_1.HTTPException(500, { message: 'Internal Server Error while getting pool info.' });
    }
});
// Estimate gas for pool creation
pool.post('/estimate-gas', async (c) => {
    try {
        const body = await c.req.json();
        const { token0, token1, fee, tickSpacing, hookAddress, initialPriceX96 } = body;
        // Basic validation
        if (!token0 || !token1 || !hookAddress || !fee || !tickSpacing) {
            return c.json({ success: false, message: 'All pool parameters are required.' }, 400);
        }
        console.log(`Estimating gas for pool creation: ${token0}/${token1}`);
        const result = await (0, poolService_1.estimatePoolCreationGas)({
            token0,
            token1,
            fee,
            tickSpacing,
            hookAddress,
            initialPriceX96: initialPriceX96 || '79228162514264337593543950336'
        });
        return c.json(result, 200);
    }
    catch (error) {
        console.error('Error in POST /api/pool/estimate-gas:', error);
        throw new http_exception_1.HTTPException(500, { message: 'Internal Server Error while estimating gas.' });
    }
});
// Simulate pool creation
pool.post('/simulate', async (c) => {
    try {
        const body = await c.req.json();
        const { token0, token1, fee, tickSpacing, hookAddress, initialPriceX96 } = body;
        // Basic validation
        if (!token0 || !token1 || !hookAddress || !fee || !tickSpacing) {
            return c.json({ success: false, message: 'All pool parameters are required.' }, 400);
        }
        console.log(`Simulating pool creation: ${token0}/${token1}`);
        const result = await (0, poolService_1.simulatePoolCreation)({
            token0,
            token1,
            fee,
            tickSpacing,
            hookAddress,
            initialPriceX96: initialPriceX96 || '79228162514264337593543950336'
        });
        return c.json(result, 200);
    }
    catch (error) {
        console.error('Error in POST /api/pool/simulate:', error);
        throw new http_exception_1.HTTPException(500, { message: 'Internal Server Error while simulating pool creation.' });
    }
});
// Health check
pool.get('/health', (c) => {
    return c.json({
        status: 'Pool routes healthy',
        endpoints: [
            'POST /create - Create pool with hook',
            'GET /:poolId/info - Get pool information',
            'POST /estimate-gas - Estimate pool creation gas',
            'POST /simulate - Simulate pool creation'
        ]
    });
});
exports.default = pool;
