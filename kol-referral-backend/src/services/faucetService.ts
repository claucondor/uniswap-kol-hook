import { ethers } from 'ethers';
import {
  FAUCET_AMOUNT_KOLTEST1_STR,
  FAUCET_AMOUNT_KOLTEST2_STR,
  faucetRateLimiter,
  FAUCET_RATE_LIMIT_WINDOW_MS,
  FAUCET_RATE_LIMIT_MAX_REQUESTS,
} from '@/config';
import { sendKolTest1Tokens, sendKolTest2Tokens } from '@/services/blockchain';

// Helper to convert faucet string amounts (full tokens) to wei (bigint)
// Assumes 18 decimals for simplicity, as KOLTEST tokens likely have this standard
const TOKEN_DECIMALS = 18;

function getFaucetAmountWei(amountStr: string): bigint {
  try {
    return ethers.parseUnits(amountStr, TOKEN_DECIMALS);
  } catch (error) {
    console.error(`Invalid faucet amount string: ${amountStr}. Defaulting to 0.`, error);
    return 0n;
  }
}

export const FAUCET_AMOUNT_KOLTEST1_WEI = getFaucetAmountWei(FAUCET_AMOUNT_KOLTEST1_STR);
export const FAUCET_AMOUNT_KOLTEST2_WEI = getFaucetAmountWei(FAUCET_AMOUNT_KOLTEST2_STR);

/**
 * Checks if a user (identified by key, e.g., IP or address) is rate-limited.
 * @param key Identifier for the user (e.g., IP address or user wallet address)
 * @returns True if rate-limited, false otherwise.
 */
function isRateLimited(key: string): boolean {
  const now = Date.now();
  const entry = faucetRateLimiter.get(key);

  if (entry) {
    if (now - entry.timestamp < FAUCET_RATE_LIMIT_WINDOW_MS) {
      if (entry.count >= FAUCET_RATE_LIMIT_MAX_REQUESTS) {
        console.log(`Rate limit exceeded for ${key}`);
        return true; // Still within window and count exceeded
      }
      // Within window, but count not exceeded, so update count
      faucetRateLimiter.set(key, { timestamp: entry.timestamp, count: entry.count + 1 });
      return false;
    }
  }
  // No entry or entry is outdated, so create/reset entry
  faucetRateLimiter.set(key, { timestamp: now, count: 1 });
  return false;
}

export async function requestTokensFromFaucet(userAddress: string, clientIp: string): Promise<{ success: boolean; message: string; txHash1?: string; txHash2?: string }> {
  const rateLimitKey = userAddress; // Or use clientIp, or a combination
  if (isRateLimited(rateLimitKey)) {
    return { success: false, message: 'Rate limit exceeded. Please try again later.' };
  }

  if (!ethers.isAddress(userAddress)) {
    return { success: false, message: 'Invalid user address provided.' };
  }

  if (FAUCET_AMOUNT_KOLTEST1_WEI === 0n && FAUCET_AMOUNT_KOLTEST2_WEI === 0n) {
    return { success: false, message: 'Faucet amounts are not configured correctly (or are zero).' };
  }

  let tx1Response: ethers.TransactionResponse | undefined;
  let tx2Response: ethers.TransactionResponse | undefined;
  let errorMessages = [];

  try {
    console.log(`Attempting to send tokens to ${userAddress} from faucet.`);
    if (FAUCET_AMOUNT_KOLTEST1_WEI > 0n) {
      tx1Response = await sendKolTest1Tokens(userAddress, FAUCET_AMOUNT_KOLTEST1_WEI);
      console.log(`KOLTEST1 sent. Tx hash: ${tx1Response.hash}`);
    }
    if (FAUCET_AMOUNT_KOLTEST2_WEI > 0n) {
      tx2Response = await sendKolTest2Tokens(userAddress, FAUCET_AMOUNT_KOLTEST2_WEI);
      console.log(`KOLTEST2 sent. Tx hash: ${tx2Response.hash}`);
    }

    let successMessage = 'Tokens sent successfully.';
    if (!tx1Response && FAUCET_AMOUNT_KOLTEST1_WEI > 0n) successMessage += ' (KOLTEST1 skipped or failed before send)';
    if (!tx2Response && FAUCET_AMOUNT_KOLTEST2_WEI > 0n) successMessage += ' (KOLTEST2 skipped or failed before send)';

    return {
      success: true,
      message: successMessage,
      txHash1: tx1Response?.hash,
      txHash2: tx2Response?.hash,
    };
  } catch (error: any) {
    console.error(`Faucet error for ${userAddress}:`, error);
    errorMessages.push(`Failed to send tokens: ${error.message || 'Unknown error'}`);
    // Rollback rate limit count if transaction fails before sending, or if only one of two fails?
    // For simplicity, current rate limit stands once an attempt is made.
    return {
      success: false,
      message: `Faucet attempt failed. ${errorMessages.join('; ')}`,
      txHash1: tx1Response?.hash, // Include hash if one tx succeeded before another failed
      txHash2: tx2Response?.hash,
    };
  }
} 