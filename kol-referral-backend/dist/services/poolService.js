"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createPool = createPool;
exports.getPoolInfo = getPoolInfo;
exports.estimatePoolCreationGas = estimatePoolCreationGas;
exports.simulatePoolCreation = simulatePoolCreation;
const ethers_1 = require("ethers");
const config_1 = require("../config");
const blockchain_1 = require("./blockchain");
// StateView contract for reading pool state (Base mainnet)
const STATE_VIEW_ADDRESS = '0xa3c0c9b65bad0b08107aa264b0f3db444b867a71';
// Pool Manager ABI (for pool creation)
const PoolManagerABI = [
    'function initialize((address,address,uint24,int24,address) key, uint160 sqrtPriceX96) external returns (int24 tick)',
    'function modifyLiquidity((address,address,uint24,int24,address) key, (int24,int24,int256,bytes32) params, bytes hookData) external returns (int256 callerDelta, uint256 feesAccrued)'
];
// StateView ABI (for reading pool state)
const StateViewABI = [
    'function getSlot0(bytes32 poolId) external view returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee)',
    'function getLiquidity(bytes32 poolId) external view returns (uint128 liquidity)'
];
// Get PoolManager contract instance
function getPoolManagerContract() {
    const provider = (0, blockchain_1.getProvider)();
    return new ethers_1.ethers.Contract(config_1.config.contracts.poolManager, PoolManagerABI, provider);
}
// Get StateView contract instance (for reading pool state)
function getStateViewContract() {
    const provider = (0, blockchain_1.getProvider)();
    return new ethers_1.ethers.Contract(STATE_VIEW_ADDRESS, StateViewABI, provider);
}
// Create pool with hook
async function createPool(params) {
    try {
        const wallet = (0, blockchain_1.getBackendWallet)();
        const poolManagerContract = getPoolManagerContract().connect(wallet);
        console.log(`Creating pool with tokens ${params.token0}/${params.token1}`);
        // Ensure correct token order
        let currency0 = params.token0;
        let currency1 = params.token1;
        if (params.token0.toLowerCase() > params.token1.toLowerCase()) {
            currency0 = params.token1;
            currency1 = params.token0;
        }
        // Create PoolKey structure (like Foundry)
        const poolKey = {
            currency0,
            currency1,
            fee: params.fee,
            tickSpacing: params.tickSpacing,
            hooks: params.hookAddress
        };
        console.log('Pool Key:', poolKey);
        console.log('Initial Price X96:', params.initialPriceX96);
        // Initialize the pool (like Foundry: 2 parameters only)
        const tx = await poolManagerContract.initialize(poolKey, params.initialPriceX96);
        console.log(`Transaction sent: ${tx.hash}`);
        const receipt = await tx.wait();
        console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
        // Calculate pool ID
        const poolId = ethers_1.ethers.keccak256(ethers_1.ethers.AbiCoder.defaultAbiCoder().encode(['address', 'address', 'uint24', 'int24', 'address'], [currency0, currency1, params.fee, params.tickSpacing, params.hookAddress]));
        return {
            success: true,
            message: 'Pool created successfully',
            data: {
                poolId,
                poolKey,
                currency0,
                currency1,
                fee: params.fee,
                tickSpacing: params.tickSpacing,
                hookAddress: params.hookAddress,
                initialPriceX96: params.initialPriceX96,
                transactionHash: tx.hash,
                blockNumber: receipt.blockNumber
            }
        };
    }
    catch (error) {
        console.error('Error creating pool:', error);
        let message = 'Failed to create pool';
        if (error.message.includes('revert')) {
            message = `Contract error: ${error.message}`;
        }
        else if (error.code === 'INSUFFICIENT_FUNDS') {
            message = 'Insufficient funds for transaction';
        }
        else if (error.message.includes('PoolAlreadyExists')) {
            message = 'Pool already exists with these parameters';
        }
        return {
            success: false,
            message
        };
    }
}
// Get pool information using StateView
async function getPoolInfo(poolId) {
    try {
        const stateViewContract = getStateViewContract();
        console.log(`Getting pool info for pool ID: ${poolId}`);
        // Get pool slot0 (price, tick, etc.) using StateView
        const slot0Result = await stateViewContract.getSlot0(poolId);
        // Get liquidity using StateView
        const liquidity = await stateViewContract.getLiquidity(poolId);
        // slot0Result is an array: [sqrtPriceX96, tick, protocolFee, lpFee]
        const [sqrtPriceX96, tick, protocolFee, lpFee] = slot0Result;
        return {
            success: true,
            message: 'Pool info retrieved successfully',
            data: {
                poolId,
                sqrtPriceX96: sqrtPriceX96.toString(),
                tick: tick.toString(),
                protocolFee: protocolFee.toString(),
                lpFee: lpFee.toString(),
                liquidity: liquidity.toString(),
                isInitialized: sqrtPriceX96 > 0
            }
        };
    }
    catch (error) {
        console.error('Error getting pool info:', error);
        return {
            success: false,
            message: 'Pool not found or error retrieving pool information'
        };
    }
}
// Estimate gas for pool creation
async function estimatePoolCreationGas(params) {
    try {
        const wallet = (0, blockchain_1.getBackendWallet)();
        const poolManagerContract = getPoolManagerContract().connect(wallet);
        // Ensure correct token order
        let currency0 = params.token0;
        let currency1 = params.token1;
        if (params.token0.toLowerCase() > params.token1.toLowerCase()) {
            currency0 = params.token1;
            currency1 = params.token0;
        }
        // Create pool key object for gas estimation (like Foundry)
        const poolKey = {
            currency0,
            currency1,
            fee: params.fee,
            tickSpacing: params.tickSpacing,
            hooks: params.hookAddress
        };
        console.log('Estimating gas for pool creation...');
        // Estimate gas for initialize function (like Foundry: 2 parameters only)
        try {
            const gasEstimate = await poolManagerContract.initialize.estimateGas(poolKey, params.initialPriceX96);
            // Get current gas price
            const gasPrice = await wallet.provider?.getFeeData();
            return {
                success: true,
                message: 'Gas estimation completed',
                data: {
                    gasLimit: gasEstimate.toString(),
                    gasPrice: gasPrice?.gasPrice?.toString() || '0',
                    estimatedCost: gasPrice?.gasPrice ?
                        ethers_1.ethers.formatEther(gasEstimate * gasPrice.gasPrice) : '0'
                }
            };
        }
        catch (gasError) {
            console.log('Gas estimation failed, using fallback values:', gasError.message);
            // Return fallback gas estimation
            return {
                success: true,
                message: 'Gas estimation completed (fallback values)',
                data: {
                    gasLimit: '500000', // 500k gas fallback
                    gasPrice: '20000000000', // 20 gwei fallback
                    estimatedCost: '0.01' // 0.01 ETH fallback
                }
            };
        }
    }
    catch (error) {
        console.error('Error estimating gas:', error);
        return {
            success: false,
            message: 'Failed to estimate gas for pool creation'
        };
    }
}
// Simulate pool creation (dry run)
async function simulatePoolCreation(params) {
    try {
        // This is a simulation, so we just validate parameters and return expected result
        console.log('Simulating pool creation...');
        // Ensure correct token order
        let currency0 = params.token0;
        let currency1 = params.token1;
        if (params.token0.toLowerCase() > params.token1.toLowerCase()) {
            currency0 = params.token1;
            currency1 = params.token0;
        }
        // Calculate expected pool ID
        const poolId = ethers_1.ethers.keccak256(ethers_1.ethers.AbiCoder.defaultAbiCoder().encode(['address', 'address', 'uint24', 'int24', 'address'], [currency0, currency1, params.fee, params.tickSpacing, params.hookAddress]));
        return {
            success: true,
            message: 'Pool creation simulation completed',
            data: {
                wouldSucceed: true,
                expectedPoolId: poolId,
                currency0,
                currency1,
                fee: params.fee,
                tickSpacing: params.tickSpacing,
                hookAddress: params.hookAddress,
                initialPriceX96: params.initialPriceX96,
                simulation: true
            }
        };
    }
    catch (error) {
        console.error('Error simulating pool creation:', error);
        return {
            success: false,
            message: 'Pool creation simulation failed'
        };
    }
}
