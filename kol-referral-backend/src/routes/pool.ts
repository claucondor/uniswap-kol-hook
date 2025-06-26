import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { ethers } from 'ethers';
import { createPool, getPoolInfo, estimatePoolCreationGas, simulatePoolCreation, addLiquidity, getTokenBalances } from '../services/poolService';

const pool = new Hono();

// Create pool with hook
pool.post('/create', async (c) => {
  try {
    const body = await c.req.json<{
      token0: string;
      token1: string;
      fee: number;
      tickSpacing: number;
      hookAddress: string;
      initialPriceX96?: string;
      userAddress: string;
    }>();

    const { token0, token1, fee, tickSpacing, hookAddress, initialPriceX96, userAddress } = body;

    // Validation
    if (!token0 || !ethers.isAddress(token0)) {
      return c.json({ success: false, message: 'Valid token0 address is required.' }, 400);
    }

    if (!token1 || !ethers.isAddress(token1)) {
      return c.json({ success: false, message: 'Valid token1 address is required.' }, 400);
    }

    if (!hookAddress || !ethers.isAddress(hookAddress)) {
      return c.json({ success: false, message: 'Valid hook address is required.' }, 400);
    }

    if (!userAddress || !ethers.isAddress(userAddress)) {
      return c.json({ success: false, message: 'Valid user address is required.' }, 400);
    }

    if (!fee || fee <= 0) {
      return c.json({ success: false, message: 'Valid fee is required.' }, 400);
    }

    if (!tickSpacing || tickSpacing <= 0) {
      return c.json({ success: false, message: 'Valid tick spacing is required.' }, 400);
    }

    console.log(`Creating pool: ${token0}/${token1} with hook ${hookAddress}`);
    
    const result = await createPool({
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
  } catch (error: any) {
    console.error('Error in POST /api/pool/create:', error);
    if (error instanceof SyntaxError) {
      return c.json({ success: false, message: 'Invalid JSON payload.' }, 400);
    }
    throw new HTTPException(500, { message: 'Internal Server Error while creating pool.' });
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
    
    const result = await getPoolInfo(poolId);
    
    if (!result.success) {
      return c.json(result, 404);
    }

    return c.json(result, 200);
  } catch (error: any) {
    console.error('Error in GET /api/pool/:poolId/info:', error);
    throw new HTTPException(500, { message: 'Internal Server Error while getting pool info.' });
  }
});

// Estimate gas for pool creation
pool.post('/estimate-gas', async (c) => {
  try {
    const body = await c.req.json<{
      token0: string;
      token1: string;
      fee: number;
      tickSpacing: number;
      hookAddress: string;
      initialPriceX96?: string;
    }>();

    const { token0, token1, fee, tickSpacing, hookAddress, initialPriceX96 } = body;

    // Basic validation
    if (!token0 || !token1 || !hookAddress || !fee || !tickSpacing) {
      return c.json({ success: false, message: 'All pool parameters are required.' }, 400);
    }

    console.log(`Estimating gas for pool creation: ${token0}/${token1}`);
    
    const result = await estimatePoolCreationGas({
      token0,
      token1,
      fee,
      tickSpacing,
      hookAddress,
      initialPriceX96: initialPriceX96 || '79228162514264337593543950336'
    });
    
    return c.json(result, 200);
  } catch (error: any) {
    console.error('Error in POST /api/pool/estimate-gas:', error);
    throw new HTTPException(500, { message: 'Internal Server Error while estimating gas.' });
  }
});

// Simulate pool creation
pool.post('/simulate', async (c) => {
  try {
    const body = await c.req.json<{
      token0: string;
      token1: string;
      fee: number;
      tickSpacing: number;
      hookAddress: string;
      initialPriceX96?: string;
    }>();

    const { token0, token1, fee, tickSpacing, hookAddress, initialPriceX96 } = body;

    // Basic validation
    if (!token0 || !token1 || !hookAddress || !fee || !tickSpacing) {
      return c.json({ success: false, message: 'All pool parameters are required.' }, 400);
    }

    console.log(`Simulating pool creation: ${token0}/${token1}`);
    
    const result = await simulatePoolCreation({
      token0,
      token1,
      fee,
      tickSpacing,
      hookAddress,
      initialPriceX96: initialPriceX96 || '79228162514264337593543950336'
    });
    
    return c.json(result, 200);
  } catch (error: any) {
    console.error('Error in POST /api/pool/simulate:', error);
    throw new HTTPException(500, { message: 'Internal Server Error while simulating pool creation.' });
  }
});

// Add liquidity to pool
pool.post('/add-liquidity', async (c) => {
  try {
    const body = await c.req.json<{
      poolId: string;
      token0: string;
      token1: string;
      fee: number;
      tickSpacing: number;
      hookAddress: string;
      amount0: string;
      amount1: string;
      userAddress: string;
      tickLower?: number;
      tickUpper?: number;
    }>();

    const { 
      poolId, 
      token0, 
      token1, 
      fee, 
      tickSpacing, 
      hookAddress, 
      amount0, 
      amount1, 
      userAddress,
      tickLower,
      tickUpper 
    } = body;

    // Validation
    if (!poolId) {
      return c.json({ success: false, message: 'Pool ID is required.' }, 400);
    }

    if (!token0 || !ethers.isAddress(token0)) {
      return c.json({ success: false, message: 'Valid token0 address is required.' }, 400);
    }

    if (!token1 || !ethers.isAddress(token1)) {
      return c.json({ success: false, message: 'Valid token1 address is required.' }, 400);
    }

    if (!hookAddress || !ethers.isAddress(hookAddress)) {
      return c.json({ success: false, message: 'Valid hook address is required.' }, 400);
    }

    if (!userAddress || !ethers.isAddress(userAddress)) {
      return c.json({ success: false, message: 'Valid user address is required.' }, 400);
    }

    if (!fee || fee <= 0) {
      return c.json({ success: false, message: 'Valid fee is required.' }, 400);
    }

    if (!tickSpacing || tickSpacing <= 0) {
      return c.json({ success: false, message: 'Valid tick spacing is required.' }, 400);
    }

    if (!amount0 || parseFloat(amount0) <= 0) {
      return c.json({ success: false, message: 'Valid amount0 is required.' }, 400);
    }

    if (!amount1 || parseFloat(amount1) <= 0) {
      return c.json({ success: false, message: 'Valid amount1 is required.' }, 400);
    }

    console.log(`Adding liquidity to pool ${poolId} for user ${userAddress}`);
    
    const result = await addLiquidity({
      poolId,
      token0,
      token1,
      fee,
      tickSpacing,
      hookAddress,
      amount0,
      amount1,
      userAddress,
      tickLower,
      tickUpper
    });
    
    if (!result.success) {
      return c.json(result, 400);
    }

    return c.json(result, 200);
  } catch (error: any) {
    console.error('Error in POST /api/pool/add-liquidity:', error);
    if (error instanceof SyntaxError) {
      return c.json({ success: false, message: 'Invalid JSON payload.' }, 400);
    }
    throw new HTTPException(500, { message: 'Internal Server Error while adding liquidity.' });
  }
});

// Get token balances for user
pool.get('/balances/:userAddress', async (c) => {
  try {
    const userAddress = c.req.param('userAddress');
    const tokensParam = c.req.query('tokens');
    
    if (!userAddress || !ethers.isAddress(userAddress)) {
      return c.json({ success: false, message: 'Valid user address is required.' }, 400);
    }

    // Default to KOLTEST tokens if not specified (UPDATED ADDRESSES)
    const defaultTokens = [
      '0x52bc5Caf2520c31a7669A7FAaD0F8E37aF53c5D3', // KOLTEST1 (NEW)
      '0xFe3Ad79f52CD53bf8e948A32936d7d5EB53f00a7'  // KOLTEST2 (NEW)
    ];
    
    const tokens = tokensParam ? tokensParam.split(',') : defaultTokens;
    
    // Validate token addresses
    for (const token of tokens) {
      if (!ethers.isAddress(token)) {
        return c.json({ success: false, message: `Invalid token address: ${token}` }, 400);
      }
    }

    console.log(`Getting balances for user ${userAddress}, tokens: ${tokens.join(', ')}`);
    
    const result = await getTokenBalances(userAddress, tokens);
    
    if (!result.success) {
      return c.json(result, 400);
    }

    return c.json(result, 200);
  } catch (error: any) {
    console.error('Error in GET /api/pool/balances/:userAddress:', error);
    throw new HTTPException(500, { message: 'Internal Server Error while getting token balances.' });
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
      'POST /simulate - Simulate pool creation',
      'POST /add-liquidity - Add liquidity to pool',
      'GET /balances/:userAddress - Get token balances for user'
    ]
  });
});

export default pool; 