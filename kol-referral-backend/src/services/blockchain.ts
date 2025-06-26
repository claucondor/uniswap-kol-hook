import { ethers, Contract, Wallet, JsonRpcProvider } from 'ethers';
import {
  RPC_URL,
  BACKEND_WALLET_PRIVATE_KEY,
  KOLTEST1_ADDRESS,
  KOLTEST2_ADDRESS,
  // REFERRAL_REGISTRY_ADDRESS, // Add if KOL stats endpoint is implemented
  // REFERRAL_HOOK_V2_ADDRESS, // Add if KOL stats endpoint is implemented
} from '@/config';
import erc20Abi from '@/abis/erc20.abi.json';

let provider: JsonRpcProvider;
let backendWallet: Wallet;
let kolTest1Contract: Contract;
let kolTest2Contract: Contract;
// let referralRegistryContract: Contract; // Add if KOL stats endpoint is implemented
// let referralHookContract: Contract; // Add if KOL stats endpoint is implemented

// Gas management
let lastNonce: number | null = null;
const GAS_LIMIT = 100000n;
const GAS_MULTIPLIER = 1.2; // 20% buffer for gas price

export function initializeBlockchainServices() {
  if (!BACKEND_WALLET_PRIVATE_KEY || BACKEND_WALLET_PRIVATE_KEY === 'your_backend_wallet_private_key_here') {
    console.error('FATAL: BACKEND_WALLET_PRIVATE_KEY is not configured. Faucet will not work.');
    throw new Error('BACKEND_WALLET_PRIVATE_KEY is not configured.');
  }
  provider = new JsonRpcProvider(RPC_URL);
  backendWallet = new Wallet(BACKEND_WALLET_PRIVATE_KEY, provider);

  kolTest1Contract = new Contract(KOLTEST1_ADDRESS, erc20Abi, backendWallet);
  kolTest2Contract = new Contract(KOLTEST2_ADDRESS, erc20Abi, backendWallet);

  // Placeholder for other contracts if KOL stats endpoint is built
  // referralRegistryContract = new Contract(REFERRAL_REGISTRY_ADDRESS, referralRegistryAbi, provider); 
  // referralHookContract = new Contract(REFERRAL_HOOK_V2_ADDRESS, referralHookAbi, provider);

  console.log(`Blockchain services initialized. Wallet address: ${backendWallet.address}`);
  checkBackendWalletBalance();
}

// Export provider and wallet for other services
export function getProvider(): JsonRpcProvider {
  if (!provider) {
    throw new Error('Blockchain services not initialized. Call initializeBlockchainServices() first.');
  }
  return provider;
}

export function getBackendWallet(): Wallet {
  if (!backendWallet) {
    throw new Error('Blockchain services not initialized. Call initializeBlockchainServices() first.');
  }
  return backendWallet;
}

async function getNextNonce(): Promise<number> {
  const currentNonce = await provider.getTransactionCount(backendWallet.address, 'pending');
  
  if (lastNonce === null || currentNonce > lastNonce) {
    lastNonce = currentNonce;
  } else {
    lastNonce = lastNonce + 1;
  }
  
  return lastNonce;
}

async function getGasSettings() {
  try {
    const feeData = await provider.getFeeData();
    const gasPrice = feeData.gasPrice;
    
    if (!gasPrice) {
      throw new Error('Unable to get gas price');
    }
    
    // Add 20% buffer to gas price to avoid replacement issues
    const adjustedGasPrice = gasPrice * BigInt(Math.floor(GAS_MULTIPLIER * 100)) / 100n;
    
    return {
      gasLimit: GAS_LIMIT,
      gasPrice: adjustedGasPrice,
    };
  } catch (error) {
    console.error('Error getting gas settings:', error);
    // Fallback gas settings
    return {
      gasLimit: GAS_LIMIT,
      gasPrice: ethers.parseUnits('20', 'gwei'), // 20 gwei fallback
    };
  }
}

async function checkBackendWalletBalance() {
  try {
    const balance = await provider.getBalance(backendWallet.address);
    console.log(`Backend wallet ETH balance: ${ethers.formatEther(balance)} ETH`);
    if (balance === 0n) {
      console.warn('Warning: Backend wallet has 0 ETH. Faucet transactions will fail due to lack of gas.');
    }

    const token1Balance = await kolTest1Contract.balanceOf(backendWallet.address);
    // Assuming 18 decimals for display, fetch dynamically if necessary
    console.log(`Backend wallet KOLTEST1 balance: ${ethers.formatUnits(token1Balance, 18)}`); 

    const token2Balance = await kolTest2Contract.balanceOf(backendWallet.address);
    console.log(`Backend wallet KOLTEST2 balance: ${ethers.formatUnits(token2Balance, 18)}`);

  } catch (error) {
    console.error('Error fetching backend wallet balances:', error);
  }
}

export async function sendKolTest1Tokens(toAddress: string, amountWei: bigint): Promise<ethers.TransactionResponse> {
  if (!kolTest1Contract) throw new Error('kolTest1Contract not initialized');
  
  console.log(`Sending ${ethers.formatUnits(amountWei, 18)} KOLTEST1 to ${toAddress}`);
  
  const gasSettings = await getGasSettings();
  const nonce = await getNextNonce();
  
  return kolTest1Contract.transfer(toAddress, amountWei, {
    ...gasSettings,
    nonce,
  });
}

export async function sendKolTest2Tokens(toAddress: string, amountWei: bigint): Promise<ethers.TransactionResponse> {
  if (!kolTest2Contract) throw new Error('kolTest2Contract not initialized');
  
  console.log(`Sending ${ethers.formatUnits(amountWei, 18)} KOLTEST2 to ${toAddress}`);
  
  // Add a small delay to avoid nonce conflicts
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  const gasSettings = await getGasSettings();
  const nonce = await getNextNonce();
  
  return kolTest2Contract.transfer(toAddress, amountWei, {
    ...gasSettings,
    nonce,
  });
}

// Add functions for KOL stats if implementing that endpoint
// export async function getKOLStatsFromContracts(kolAddress: string) { ... } 