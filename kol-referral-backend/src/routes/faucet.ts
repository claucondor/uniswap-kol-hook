import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { requestTokensFromFaucet } from '@/services/faucetService';
import { ethers } from 'ethers';

const faucet = new Hono();

faucet.post('/', async (c) => {
  try {
    const body = await c.req.json<{ userAddress: string }>();
    const userAddress = body.userAddress;

    if (!userAddress || !ethers.isAddress(userAddress)) {
      return c.json({ success: false, message: 'Valid userAddress is required.' }, 400);
    }

    // Attempt to get client IP for rate limiting, though it can be spoofed
    // and might be more complex behind proxies like Cloud Run.
    // For Cloud Run, 'X-Forwarded-For' header is typically used.
    const clientIp = c.req.header('X-Forwarded-For')?.split(',')[0].trim() || c.req.header('True-Client-IP') || 'unknown-ip';
    console.log(`Faucet request for ${userAddress} from IP: ${clientIp}`);

    const result = await requestTokensFromFaucet(userAddress, clientIp);

    if (!result.success) {
      // Distinguish between bad request (e.g. rate limit) and server error
      if (result.message.toLowerCase().includes('rate limit')) {
        return c.json(result, 429); // 429 Too Many Requests
      }
      return c.json(result, 400); // 400 Bad Request for other logical failures by user
    }

    return c.json(result, 200);
  } catch (error: any) {
    console.error('Error in POST /api/faucet:', error);
    if (error instanceof SyntaxError) { // JSON parsing error
        return c.json({ success: false, message: 'Invalid JSON payload.'}, 400);
    }
    // For other errors, throw a generic server error
    throw new HTTPException(500, { message: 'Internal Server Error while processing faucet request.' });
  }
});

// Simple health check for the faucet route
faucet.get('/health', (c) => {
  return c.json({ status: 'Faucet route is healthy' });
});

export default faucet; 