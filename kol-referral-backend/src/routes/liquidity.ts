import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { ethers } from 'ethers';
import { 
  addLiquidity, 
  removeLiquidity, 
  getUserPositions, 
  estimateLiquidityGas,
  simulateLiquidityAddition 
} from '../services/liquidityService';

const liquidity = new Hono();

// Add liquidity (for referred users)
liquidity.post('/add', async (c) => {
  try {
    const body = await c.req.json<{
      poolId: string;
      token0: string;
      token1: string;
      fee: number;
      tickSpacing: number;
      hookAddress: string;
      tickLower: number;
      tickUpper: number;
      amount0Desired: string;
      amount1Desired: string;
      amount0Min?: string;
      amount1Min?: string;
      userAddress: string;
      referralCode?: string;
    }>();

    const { 
      poolId, token0, token1, fee, tickSpacing, hookAddress,
      tickLower, tickUpper, amount0Desired, amount1Desired, 
      amount0Min, amount1Min, userAddress, referralCode 
    } = body;

    // Validation
    if (!userAddress || !ethers.isAddress(userAddress)) {
      return c.json({ success: false, message: 'Valid user address is required.' }, 400);
    }

    if (!token0 || !ethers.isAddress(token0)) {
      return c.json({ success: false, message: 'Valid token0 address is required.' }, 400);
    }

    if (!token1 || !ethers.isAddress(token1)) {
      return c.json({ success: false, message: 'Valid token1 address is required.' }, 400);
    }

    if (!amount0Desired || !amount1Desired) {
      return c.json({ success: false, message: 'Desired amounts are required.' }, 400);
    }

    console.log(`Adding liquidity for user ${userAddress} to pool ${poolId}`);
    
    const result = await addLiquidity({
      poolId,
      token0,
      token1,
      fee,
      tickSpacing,
      hookAddress,
      tickLower,
      tickUpper,
      amount0Desired,
      amount1Desired,
      amount0Min: amount0Min || '0',
      amount1Min: amount1Min || '0',
      userAddress,
      referralCode
    });
    
    if (!result.success) {
      return c.json(result, 400);
    }

    return c.json(result, 201);
  } catch (error: any) {
    console.error('Error in POST /api/liquidity/add:', error);
    if (error instanceof SyntaxError) {
      return c.json({ success: false, message: 'Invalid JSON payload.' }, 400);
    }
    throw new HTTPException(500, { message: 'Internal Server Error while adding liquidity.' });
  }
});

// Remove liquidity
liquidity.post('/remove', async (c) => {
  try {
    const body = await c.req.json<{
      poolId: string;
      token0: string;
      token1: string;
      fee: number;
      tickSpacing: number;
      hookAddress: string;
      tickLower: number;
      tickUpper: number;
      liquidity: string;
      amount0Min?: string;
      amount1Min?: string;
      userAddress: string;
    }>();

    const { 
      poolId, token0, token1, fee, tickSpacing, hookAddress,
      tickLower, tickUpper, liquidity, amount0Min, amount1Min, userAddress 
    } = body;

    // Validation
    if (!userAddress || !ethers.isAddress(userAddress)) {
      return c.json({ success: false, message: 'Valid user address is required.' }, 400);
    }

    if (!liquidity) {
      return c.json({ success: false, message: 'Liquidity amount is required.' }, 400);
    }

    console.log(`Removing liquidity for user ${userAddress} from pool ${poolId}`);
    
    const result = await removeLiquidity({
      poolId,
      token0,
      token1,
      fee,
      tickSpacing,
      hookAddress,
      tickLower,
      tickUpper,
      liquidity,
      amount0Min: amount0Min || '0',
      amount1Min: amount1Min || '0',
      userAddress
    });
    
    if (!result.success) {
      return c.json(result, 400);
    }

    return c.json(result, 200);
  } catch (error: any) {
    console.error('Error in POST /api/liquidity/remove:', error);
    throw new HTTPException(500, { message: 'Internal Server Error while removing liquidity.' });
  }
});

// Get user liquidity positions
liquidity.get('/user/:userAddress', async (c) => {
  try {
    const userAddress = c.req.param('userAddress');
    
    if (!userAddress || !ethers.isAddress(userAddress)) {
      return c.json({ success: false, message: 'Valid user address is required.' }, 400);
    }

    console.log(`Getting liquidity positions for user: ${userAddress}`);
    
    const result = await getUserPositions(userAddress);
    
    if (!result.success) {
      return c.json(result, 404);
    }

    return c.json(result, 200);
  } catch (error: any) {
    console.error('Error in GET /api/liquidity/user:', error);
    throw new HTTPException(500, { message: 'Internal Server Error while getting user positions.' });
  }
});

// Estimate gas for liquidity operations
liquidity.post('/estimate-gas', async (c) => {
  try {
    const body = await c.req.json<{
      operation: 'add' | 'remove';
      poolId: string;
      token0: string;
      token1: string;
      amount0: string;
      amount1: string;
      userAddress: string;
    }>();

    const { operation, poolId, token0, token1, amount0, amount1, userAddress } = body;

    // Basic validation
    if (!operation || !poolId || !userAddress) {
      return c.json({ success: false, message: 'Operation, pool ID, and user address are required.' }, 400);
    }

    console.log(`Estimating gas for ${operation} liquidity operation`);
    
    const result = await estimateLiquidityGas({
      operation,
      poolId,
      token0,
      token1,
      amount0,
      amount1,
      userAddress
    });
    
    return c.json(result, 200);
  } catch (error: any) {
    console.error('Error in POST /api/liquidity/estimate-gas:', error);
    throw new HTTPException(500, { message: 'Internal Server Error while estimating gas.' });
  }
});

// Simulate liquidity addition
liquidity.post('/simulate', async (c) => {
  try {
    const body = await c.req.json<{
      poolId: string;
      token0: string;
      token1: string;
      amount0Desired: string;
      amount1Desired: string;
      tickLower: number;
      tickUpper: number;
      userAddress: string;
    }>();

    const { poolId, token0, token1, amount0Desired, amount1Desired, tickLower, tickUpper, userAddress } = body;

    // Basic validation
    if (!poolId || !userAddress || !amount0Desired || !amount1Desired) {
      return c.json({ success: false, message: 'All simulation parameters are required.' }, 400);
    }

    console.log(`Simulating liquidity addition for user ${userAddress}`);
    
    const result = await simulateLiquidityAddition({
      poolId,
      token0,
      token1,
      amount0Desired,
      amount1Desired,
      tickLower,
      tickUpper,
      userAddress
    });
    
    return c.json(result, 200);
  } catch (error: any) {
    console.error('Error in POST /api/liquidity/simulate:', error);
    throw new HTTPException(500, { message: 'Internal Server Error while simulating liquidity addition.' });
  }
});

// Health check
liquidity.get('/health', (c) => {
  return c.json({ 
    status: 'Liquidity routes healthy',
    endpoints: [
      'POST /add - Add liquidity to pool',
      'POST /remove - Remove liquidity from pool',
      'GET /user/:address - Get user positions',
      'POST /estimate-gas - Estimate gas for operations',
      'POST /simulate - Simulate liquidity addition'
    ]
  });
});

export default liquidity; 