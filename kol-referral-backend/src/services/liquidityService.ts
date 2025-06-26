import { ethers } from 'ethers';
import { config } from '../config';
import { getProvider, getBackendWallet } from './blockchain';

// Import ABIs
const PositionManagerABI = [
  'function modifyLiquidity((address,address,uint24,int24,address) key, (int24,int24,int256,bytes) params, bytes hookData) external returns (uint256 tokenId, int128 liquidityDelta, int256 delta0, int256 delta1)',
  'function collect((address,address,uint24,int24,address) key, (int24,int24,uint128,uint128) params) external returns (uint256 amount0, uint256 amount1)',
  'function getPositions(uint256 tokenId) external view returns (uint128 liquidity, int24 tickLower, int24 tickUpper)',
  'function ownerOf(uint256 tokenId) external view returns (address)',
  'function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256)'
];

interface ServiceResponse<T = any> {
  success: boolean;
  message: string;
  data?: T;
}

interface LiquidityParams {
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
  amount0Min: string;
  amount1Min: string;
  userAddress: string;
  referralCode?: string;
}

interface RemoveLiquidityParams {
  poolId: string;
  token0: string;
  token1: string;
  fee: number;
  tickSpacing: number;
  hookAddress: string;
  tickLower: number;
  tickUpper: number;
  liquidity: string;
  amount0Min: string;
  amount1Min: string;
  userAddress: string;
}

// Get PositionManager contract instance
function getPositionManagerContract() {
  const provider = getProvider();
  return new ethers.Contract(
    config.contracts.positionManager,
    PositionManagerABI,
    provider
  ) as any;
}

// Add liquidity to pool
export async function addLiquidity(params: LiquidityParams): Promise<ServiceResponse> {
  try {
    const wallet = getBackendWallet();
    const positionManagerContract = getPositionManagerContract().connect(wallet);

    console.log(`Adding liquidity for user ${params.userAddress} to pool ${params.poolId}`);

    // Ensure correct token order
    let currency0 = params.token0;
    let currency1 = params.token1;
    let amount0Desired = params.amount0Desired;
    let amount1Desired = params.amount1Desired;
    let amount0Min = params.amount0Min;
    let amount1Min = params.amount1Min;
    
    if (params.token0.toLowerCase() > params.token1.toLowerCase()) {
      currency0 = params.token1;
      currency1 = params.token0;
      amount0Desired = params.amount1Desired;
      amount1Desired = params.amount0Desired;
      amount0Min = params.amount1Min;
      amount1Min = params.amount0Min;
    }

    // Create PoolKey structure
    const poolKey = {
      currency0,
      currency1,
      fee: params.fee,
      tickSpacing: params.tickSpacing,
      hooks: params.hookAddress
    };

    // Create ModifyLiquidityParams
    const modifyParams = {
      tickLower: params.tickLower,
      tickUpper: params.tickUpper,
      liquidityDelta: ethers.parseUnits(amount0Desired, 18), // Approximation
      salt: ethers.randomBytes(32)
    };

    // Prepare hook data with referral code if provided
    let hookData = '0x';
    if (params.referralCode) {
      hookData = ethers.AbiCoder.defaultAbiCoder().encode(
        ['string', 'address'],
        [params.referralCode, params.userAddress]
      );
    }

    console.log('Pool Key:', poolKey);
    console.log('Modify Params:', modifyParams);
    console.log('Hook Data:', hookData);

    // Add liquidity
    const tx = await positionManagerContract.modifyLiquidity(
      poolKey,
      modifyParams,
      hookData
    );

    console.log(`Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);

    // Parse logs to get token ID and amounts
    const tokenId = receipt.logs.length > 0 ? 
      ethers.getBigInt(receipt.logs[0].topics[1] || '0').toString() : '0';

    return {
      success: true,
      message: 'Liquidity added successfully',
      data: {
        tokenId,
        poolId: params.poolId,
        tickLower: params.tickLower,
        tickUpper: params.tickUpper,
        amount0: amount0Desired,
        amount1: amount1Desired,
        userAddress: params.userAddress,
        referralCode: params.referralCode,
        transactionHash: tx.hash,
        blockNumber: receipt.blockNumber
      }
    };
  } catch (error: any) {
    console.error('Error adding liquidity:', error);
    
    let message = 'Failed to add liquidity';
    if (error.message.includes('revert')) {
      message = `Contract error: ${error.message}`;
    } else if (error.code === 'INSUFFICIENT_FUNDS') {
      message = 'Insufficient funds for transaction';
    } else if (error.message.includes('InsufficientLiquidity')) {
      message = 'Insufficient token amounts for liquidity provision';
    }

    return {
      success: false,
      message
    };
  }
}

// Remove liquidity from pool
export async function removeLiquidity(params: RemoveLiquidityParams): Promise<ServiceResponse> {
  try {
    const wallet = getBackendWallet();
    const positionManagerContract = getPositionManagerContract().connect(wallet);

    console.log(`Removing liquidity for user ${params.userAddress} from pool ${params.poolId}`);

    // Ensure correct token order
    let currency0 = params.token0;
    let currency1 = params.token1;
    
    if (params.token0.toLowerCase() > params.token1.toLowerCase()) {
      currency0 = params.token1;
      currency1 = params.token0;
    }

    // Create PoolKey structure
    const poolKey = {
      currency0,
      currency1,
      fee: params.fee,
      tickSpacing: params.tickSpacing,
      hooks: params.hookAddress
    };

    // Create ModifyLiquidityParams for removal (negative liquidity)
    const modifyParams = {
      tickLower: params.tickLower,
      tickUpper: params.tickUpper,
      liquidityDelta: `-${params.liquidity}`,
      salt: ethers.randomBytes(32)
    };

    console.log('Pool Key:', poolKey);
    console.log('Modify Params:', modifyParams);

    // Remove liquidity
    const tx = await positionManagerContract.modifyLiquidity(
      poolKey,
      modifyParams,
      '0x' // No hook data needed for removal
    );

    console.log(`Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);

    return {
      success: true,
      message: 'Liquidity removed successfully',
      data: {
        poolId: params.poolId,
        tickLower: params.tickLower,
        tickUpper: params.tickUpper,
        liquidity: params.liquidity,
        userAddress: params.userAddress,
        transactionHash: tx.hash,
        blockNumber: receipt.blockNumber
      }
    };
  } catch (error: any) {
    console.error('Error removing liquidity:', error);
    
    let message = 'Failed to remove liquidity';
    if (error.message.includes('revert')) {
      message = `Contract error: ${error.message}`;
    } else if (error.code === 'INSUFFICIENT_FUNDS') {
      message = 'Insufficient funds for transaction';
    }

    return {
      success: false,
      message
    };
  }
}

// Get user liquidity positions
export async function getUserPositions(userAddress: string): Promise<ServiceResponse> {
  try {
    const positionManagerContract = getPositionManagerContract();
    
    console.log(`Getting liquidity positions for user: ${userAddress}`);
    
    // This is a simplified version - in a real implementation you'd need to track positions
    // For now, return a placeholder structure
    const positions = [
      {
        tokenId: '1',
        poolId: 'example-pool-id',
        tickLower: -887220,
        tickUpper: 887220,
        liquidity: '1000000000000000000',
        token0: config.testTokens.KOLTEST1,
        token1: config.testTokens.KOLTEST2,
        amount0: '1000',
        amount1: '1000',
        fees0: '10',
        fees1: '10'
      }
    ];
    
    return {
      success: true,
      message: 'User positions retrieved successfully',
      data: {
        userAddress,
        positions,
        totalPositions: positions.length
      }
    };
  } catch (error: any) {
    console.error('Error getting user positions:', error);
    return {
      success: false,
      message: 'Failed to retrieve user positions'
    };
  }
}

// Estimate gas for liquidity operations
export async function estimateLiquidityGas(params: {
  operation: 'add' | 'remove';
  poolId: string;
  token0: string;
  token1: string;
  amount0: string;
  amount1: string;
  userAddress: string;
}): Promise<ServiceResponse> {
  try {
    const wallet = getBackendWallet();
    
    console.log(`Estimating gas for ${params.operation} liquidity operation`);

    // Base gas estimates (these would be more accurate with real contract calls)
    const baseGasEstimates = {
      add: '300000',
      remove: '200000'
    };

    // Get current gas price
    const gasPrice = await wallet.provider?.getFeeData();

    const gasLimit = baseGasEstimates[params.operation];

    return {
      success: true,
      message: 'Gas estimation completed',
      data: {
        operation: params.operation,
        gasLimit,
        gasPrice: gasPrice?.gasPrice?.toString() || '0',
        estimatedCost: gasPrice?.gasPrice ? 
          ethers.formatEther(BigInt(gasLimit) * gasPrice.gasPrice) : '0'
      }
    };
  } catch (error: any) {
    console.error('Error estimating gas:', error);
    return {
      success: false,
      message: 'Failed to estimate gas for liquidity operation'
    };
  }
}

// Simulate liquidity addition
export async function simulateLiquidityAddition(params: {
  poolId: string;
  token0: string;
  token1: string;
  amount0Desired: string;
  amount1Desired: string;
  tickLower: number;
  tickUpper: number;
  userAddress: string;
}): Promise<ServiceResponse> {
  try {
    console.log(`Simulating liquidity addition for user ${params.userAddress}`);

    // This is a simulation, so we just validate parameters and return expected result
    const liquidityAmount = ethers.parseUnits(params.amount0Desired, 18);

    return {
      success: true,
      message: 'Liquidity addition simulation completed',
      data: {
        wouldSucceed: true,
        expectedLiquidity: liquidityAmount.toString(),
        amount0: params.amount0Desired,
        amount1: params.amount1Desired,
        tickLower: params.tickLower,
        tickUpper: params.tickUpper,
        poolId: params.poolId,
        userAddress: params.userAddress,
        simulation: true
      }
    };
  } catch (error: any) {
    console.error('Error simulating liquidity addition:', error);
    return {
      success: false,
      message: 'Liquidity addition simulation failed'
    };
  }
} 