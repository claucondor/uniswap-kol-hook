import { useState, useCallback } from 'react';
import { ethers } from 'ethers';
import { useWeb3 } from './useWeb3';
import { CONTRACTS } from '@/config/contracts';
import toast from 'react-hot-toast';

// ABIs (following the exact same pattern as AddLiquidityNewUser.s.sol)
const ERC20_ABI = [
  'function approve(address spender, uint256 amount) external returns (bool)',
  'function allowance(address owner, address spender) external view returns (uint256)',
  'function balanceOf(address account) external view returns (uint256)',
  'function decimals() external view returns (uint8)'
];

const PERMIT2_ABI = [
  'function approve(address token, address spender, uint160 amount, uint48 expiration) external'
];

const POSITION_MANAGER_ABI = [
  'function modifyLiquidities(bytes unlockData, uint256 deadline) external payable'
];

// Removed POOL_MANAGER_ABI since we're using fixed tick ranges like the script

// Permit2 contract address on Base
const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3';

interface AddLiquidityParams {
  token0: string;
  token1: string;
  fee: number;
  tickSpacing: number;
  tickLower: number;
  tickUpper: number;
  amount0Desired: string;
  amount1Desired: string;
  amount0Min?: string;
  amount1Min?: string;
}

export function useLiquidity() {
  const { address, isConnected, getProvider } = useWeb3();
  const [isLoading, setIsLoading] = useState(false);

  const setupPermit2Approvals = useCallback(async (
    token0Address: string,
    token1Address: string,
    provider: ethers.BrowserProvider
  ) => {
    const signer = await provider.getSigner();
    
    // Step 1: Approve tokens to Permit2 (following AddLiquidityNewUser.s.sol)
    const token0Contract = new ethers.Contract(token0Address, ERC20_ABI, signer);
    const token1Contract = new ethers.Contract(token1Address, ERC20_ABI, signer);
    
    toast('Setting up Permit2 approvals...', { icon: 'ℹ️' });
    
    // Check and approve token0 to Permit2
    const allowance0 = await token0Contract.allowance(address, PERMIT2_ADDRESS);
    if (allowance0 < ethers.MaxUint256 / 2n) {
      const approveTx0 = await token0Contract.approve(PERMIT2_ADDRESS, ethers.MaxUint256);
      await approveTx0.wait();
    }
    
    // Check and approve token1 to Permit2
    const allowance1 = await token1Contract.allowance(address, PERMIT2_ADDRESS);
    if (allowance1 < ethers.MaxUint256 / 2n) {
      const approveTx1 = await token1Contract.approve(PERMIT2_ADDRESS, ethers.MaxUint256);
      await approveTx1.wait();
    }
    
    // Step 2: Give Permit2 permission to let PositionManager spend tokens
    const permit2Contract = new ethers.Contract(PERMIT2_ADDRESS, PERMIT2_ABI, signer);
    
    const maxExpiration = 2n ** 48n - 1n; // Max uint48
    const maxAmount = 2n ** 160n - 1n; // Max uint160
    
    const permit2Tx0 = await permit2Contract.approve(token0Address, CONTRACTS.POSITION_MANAGER, maxAmount, maxExpiration);
    await permit2Tx0.wait();
    
    const permit2Tx1 = await permit2Contract.approve(token1Address, CONTRACTS.POSITION_MANAGER, maxAmount, maxExpiration);
    await permit2Tx1.wait();
    
    toast.success('Permit2 approvals completed!');
  }, [address]);

  const addLiquidity = useCallback(async (params: AddLiquidityParams) => {
    if (!isConnected || !address) {
      toast.error('Please connect your wallet first');
      return null;
    }

    setIsLoading(true);
    try {
      const provider = getProvider();
      const signer = await provider.getSigner();

      // Check token balances first
      const token0Contract = new ethers.Contract(params.token0, ERC20_ABI, provider);
      const token1Contract = new ethers.Contract(params.token1, ERC20_ABI, provider);
      
      const balance0 = await token0Contract.balanceOf(address);
      const balance1 = await token1Contract.balanceOf(address);
      
      const amount0BigInt = ethers.parseEther(params.amount0Desired);
      const amount1BigInt = ethers.parseEther(params.amount1Desired);
      
      if (balance0 < amount0BigInt) {
        toast.error('Insufficient KOLTEST1 balance');
        return null;
      }
      
      if (balance1 < amount1BigInt) {
        toast.error('Insufficient KOLTEST2 balance');
        return null;
      }

      // Setup Permit2 approvals (following AddLiquidityNewUser.s.sol)
      await setupPermit2Approvals(params.token0, params.token1, provider);

      // Use fixed tick range like the script does (no need to query pool state for wide range)
      // The script uses a wide range around current price, we'll do the same
      const tickSpacing = params.tickSpacing;
      const tickLower = -1000 * tickSpacing; // Wide range
      const tickUpper = 1000 * tickSpacing;  // Wide range

      // Prepare V4 actions (following AddLiquidityNewUser.s.sol exactly)
      const Actions = {
        MINT_POSITION: 0x02,
        SETTLE_PAIR: 0x0d
      };

      // Encode actions
      const actions = ethers.solidityPacked(['uint8', 'uint8'], [Actions.MINT_POSITION, Actions.SETTLE_PAIR]);

      // IMPORTANT: Pass user address in hookData for referral resolution (like the script)
      const hookData = ethers.AbiCoder.defaultAbiCoder().encode(['address'], [address]);

      // Prepare parameters for each action (following exact structure from AddLiquidityNewUser.s.sol)
      // Use a reasonable liquidity amount (the script calculates this, but we'll use a simple approach)
      const liquidityAmount = ethers.parseEther('1000000'); // 1M liquidity units
      
      const mintPositionParams = ethers.AbiCoder.defaultAbiCoder().encode(
        ['tuple(address,address,uint24,int24,address)', 'int24', 'int24', 'uint256', 'uint128', 'uint128', 'address', 'bytes'],
        [
          [params.token0, params.token1, params.fee, params.tickSpacing, CONTRACTS.REFERRAL_HOOK], // PoolKey
          tickLower,
          tickUpper,
          liquidityAmount, // liquidity amount
          amount0BigInt, // amount0Max
          amount1BigInt, // amount1Max
          address, // recipient
          hookData // CONTAINS USER ADDRESS FOR REFERRAL RESOLUTION
        ]
      );

      const settlePairParams = ethers.AbiCoder.defaultAbiCoder().encode(
        ['address', 'address'],
        [params.token0, params.token1]
      );

      const allParams = [mintPositionParams, settlePairParams];
      
      // Encode unlock data
      const unlockData = ethers.AbiCoder.defaultAbiCoder().encode(
        ['bytes', 'bytes[]'],
        [actions, allParams]
      );

      // Execute transaction
      const positionManager = new ethers.Contract(CONTRACTS.POSITION_MANAGER, POSITION_MANAGER_ABI, signer);
      
      toast('Adding liquidity... Please confirm the transaction', { icon: '💧' });
      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
      const tx = await positionManager.modifyLiquidities(unlockData, deadline);
      
      toast('Transaction submitted, waiting for confirmation...', { icon: '⏳' });
      const receipt = await tx.wait();
      
      toast.success('Liquidity added successfully!');
      
      return {
        transactionHash: receipt.hash,
        blockNumber: receipt.blockNumber,
        gasUsed: receipt.gasUsed.toString()
      };

    } catch (error: any) {
      console.error('Error adding liquidity:', error);
      
      if (error.code === 'ACTION_REJECTED') {
        toast.error('Transaction rejected by user');
      } else if (error.code === 'INSUFFICIENT_FUNDS') {
        toast.error('Insufficient funds for gas');
      } else {
        toast.error(`Failed to add liquidity: ${error.message || 'Unknown error'}`);
      }
      
      return null;
    } finally {
      setIsLoading(false);
    }
  }, [isConnected, address, getProvider, setupPermit2Approvals]);

  const getTokenBalance = useCallback(async (tokenAddress: string) => {
    if (!isConnected || !address) return '0';

    try {
      const provider = getProvider();
      const tokenContract = new ethers.Contract(tokenAddress, ERC20_ABI, provider);
      const balance = await tokenContract.balanceOf(address);
      return ethers.formatEther(balance);
    } catch (error) {
      console.error('Error getting token balance:', error);
      return '0';
    }
  }, [isConnected, address, getProvider]);

  return {
    addLiquidity,
    getTokenBalance,
    isLoading
  };
} 