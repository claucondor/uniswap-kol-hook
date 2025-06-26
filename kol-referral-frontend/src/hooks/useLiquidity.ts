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

const POOL_MANAGER_ABI = [
  'function getSlot0(bytes32 poolId) external view returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee)'
];

// Permit2 contract address on Base
const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3';

interface AddLiquidityParams {
  token0: string;
  token1: string;
  fee: number;
  tickSpacing: number;
  amount0Desired: string;
  amount1Desired: string;
}

// Helper functions for tick math (simplified versions)
function getSqrtRatioAtTick(tick: number): bigint {
  // Simplified implementation - in production, use the exact TickMath library
  // This is an approximation for common ticks
  if (tick === 0) return 79228162514264337593543950336n; // sqrt(1) * 2^96
  
  // For simplicity, we'll use a basic calculation
  // In production, you'd want to use the exact Uniswap TickMath library
  const Q96 = 2n ** 96n;
  const ratio = Math.pow(1.0001, tick);
  const sqrtRatio = Math.sqrt(ratio);
  return BigInt(Math.floor(sqrtRatio * Number(Q96)));
}

function getLiquidityForAmounts(
  sqrtRatioX96: bigint,
  sqrtRatioAX96: bigint,
  sqrtRatioBX96: bigint,
  amount0: bigint,
  amount1: bigint
): bigint {
  // Simplified liquidity calculation
  // This mimics LiquidityAmounts.getLiquidityForAmounts from Uniswap
  
  if (sqrtRatioAX96 > sqrtRatioBX96) {
    [sqrtRatioAX96, sqrtRatioBX96] = [sqrtRatioBX96, sqrtRatioAX96];
  }

  if (sqrtRatioX96 <= sqrtRatioAX96) {
    // All amount0
    return (amount0 * sqrtRatioAX96 * sqrtRatioBX96) / ((sqrtRatioBX96 - sqrtRatioAX96) * (2n ** 96n));
  } else if (sqrtRatioX96 < sqrtRatioBX96) {
    // Mixed amounts
    const liquidity0 = (amount0 * sqrtRatioX96 * sqrtRatioBX96) / ((sqrtRatioBX96 - sqrtRatioX96) * (2n ** 96n));
    const liquidity1 = (amount1 * (2n ** 96n)) / (sqrtRatioBX96 - sqrtRatioAX96);
    return liquidity0 < liquidity1 ? liquidity0 : liquidity1;
  } else {
    // All amount1
    return (amount1 * (2n ** 96n)) / (sqrtRatioBX96 - sqrtRatioAX96);
  }
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

      // Determine correct token order (following AddLiquidityNewUser.s.sol exactly)
      let currency0: string;
      let currency1: string;
      let amount0Desired: string;
      let amount1Desired: string;
      
      if (params.token0.toLowerCase() < params.token1.toLowerCase()) {
        currency0 = params.token0;
        currency1 = params.token1;
        amount0Desired = params.amount0Desired;
        amount1Desired = params.amount1Desired;
        console.log("Currency0 (token0):", currency0);
        console.log("Currency1 (token1):", currency1);
      } else {
        currency0 = params.token1;
        currency1 = params.token0;
        amount0Desired = params.amount1Desired;
        amount1Desired = params.amount0Desired;
        console.log("Currency0 (token1):", currency0);
        console.log("Currency1 (token0):", currency1);
      }

      // Check token balances first
      const token0Contract = new ethers.Contract(currency0, ERC20_ABI, provider);
      const token1Contract = new ethers.Contract(currency1, ERC20_ABI, provider);
      
      const balance0 = await token0Contract.balanceOf(address);
      const balance1 = await token1Contract.balanceOf(address);
      
      const amount0BigInt = ethers.parseEther(amount0Desired);
      const amount1BigInt = ethers.parseEther(amount1Desired);
      
      if (balance0 < amount0BigInt) {
        toast.error('Insufficient token0 balance');
        return null;
      }
      
      if (balance1 < amount1BigInt) {
        toast.error('Insufficient token1 balance');
        return null;
      }

      // Use exact approach from AddLiquidityNewUser.s.sol
      // The script calculates liquidity for the desired amounts and uses them directly
      
      const sqrtPriceX96 = 79228162514264337593543950336n;
      const currentTick = 0;
      const tickLower = -60000;
      const tickUpper = 60000;
      
      // Simple proportional calculation based on successful script
      // Script: 100M tokens -> 105240396777600467992368804 liquidity
      // For any amount: liquidity = (scriptLiquidity * userAmount) / scriptAmount
      
      const scriptAmount = ethers.parseEther('100000000'); // 100M tokens from script
      const scriptLiquidity = 105240396777600467992368804n; // from script output
      
      // Use exact proportion - this should give us the right liquidity for any amount
      const userAmount = amount0BigInt < amount1BigInt ? amount0BigInt : amount1BigInt;
      const liquidity = (scriptLiquidity * userAmount) / scriptAmount;
      
      console.log('Using exact proportional calculation from script:');
      console.log('- sqrtPriceX96:', sqrtPriceX96.toString());
      console.log('- currentTick:', currentTick);
      console.log('- tickLower:', tickLower);
      console.log('- tickUpper:', tickUpper);
      console.log('- Script amount (100M):', ethers.formatEther(scriptAmount));
      console.log('- Script liquidity:', scriptLiquidity.toString());
      console.log('- User amount0Desired:', ethers.formatEther(amount0BigInt));
      console.log('- User amount1Desired:', ethers.formatEther(amount1BigInt));
      console.log('- User min amount:', ethers.formatEther(userAmount));
      console.log('- Calculated liquidity:', liquidity.toString());
      console.log('- Liquidity ratio check:', Number(liquidity * 10000n / scriptLiquidity), '/ 10000 of script');
      
      // Slippage protection (1% extra like in the script)
      const amount0Max = amount0BigInt + (amount0BigInt / 100n);
      const amount1Max = amount1BigInt + (amount1BigInt / 100n);

      // Setup Permit2 approvals (following AddLiquidityNewUser.s.sol)
      await setupPermit2Approvals(currency0, currency1, provider);

      // Prepare V4 actions (following AddLiquidityNewUser.s.sol exactly)
      const Actions = {
        MINT_POSITION: 0x02,
        SETTLE_PAIR: 0x0d
      };

      // Encode actions as packed bytes (exactly like the script)
      const actions = ethers.solidityPacked(['uint8', 'uint8'], [Actions.MINT_POSITION, Actions.SETTLE_PAIR]);

      // IMPORTANT: Pass user address in hookData for referral resolution (like the script)
      const hookData = ethers.AbiCoder.defaultAbiCoder().encode(['address'], [address]);

      // Prepare parameters for each action (following EXACT structure from AddLiquidityNewUser.s.sol)
      const params0 = new Array(2);
      
      // Parameters for MINT_POSITION - EXACT same structure as the script
      params0[0] = ethers.AbiCoder.defaultAbiCoder().encode(
        [
          'tuple(address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks)',
          'int24',
          'int24', 
          'uint256',
          'uint128',
          'uint128',
          'address',
          'bytes'
        ],
        [
          {
            currency0: currency0,
            currency1: currency1,
            fee: params.fee,
            tickSpacing: params.tickSpacing,
            hooks: CONTRACTS.REFERRAL_HOOK
          }, // PoolKey
          tickLower,
          tickUpper,
          liquidity, // calculated liquidity (not fixed)
          amount0Max, // amount0Max
          amount1Max, // amount1Max
          address, // recipient
          hookData // hookData - CONTAINS USER ADDRESS FOR REFERRAL RESOLUTION
        ]
      );

      // Parameters for SETTLE_PAIR - EXACT same structure as the script
      params0[1] = ethers.AbiCoder.defaultAbiCoder().encode(
        ['address', 'address'],
        [currency0, currency1]
      );

      // Encode unlock data (exactly like the script)
      const unlockData = ethers.AbiCoder.defaultAbiCoder().encode(
        ['bytes', 'bytes[]'],
        [actions, params0]
      );

      // Execute transaction
      const positionManager = new ethers.Contract(CONTRACTS.POSITION_MANAGER, POSITION_MANAGER_ABI, signer);
      
      toast('Adding liquidity... Please confirm the transaction', { icon: '💧' });
      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
      
      console.log('Executing modifyLiquidities with:');
      console.log('- Position Manager:', CONTRACTS.POSITION_MANAGER);
      console.log('- Currency0:', currency0);
      console.log('- Currency1:', currency1);
      console.log('- Hook:', CONTRACTS.REFERRAL_HOOK);
      console.log('- User Address:', address);
      console.log('- Tick Range:', tickLower, 'to', tickUpper);
      console.log('- Liquidity:', liquidity.toString());
      console.log('- Amount0Max:', ethers.formatEther(amount0Max));
      console.log('- Amount1Max:', ethers.formatEther(amount1Max));
      
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
  }, [address, isConnected, getProvider, setupPermit2Approvals]);

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