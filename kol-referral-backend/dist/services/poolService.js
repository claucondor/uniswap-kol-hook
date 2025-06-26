"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createPool = createPool;
exports.getPoolInfo = getPoolInfo;
exports.estimatePoolCreationGas = estimatePoolCreationGas;
exports.simulatePoolCreation = simulatePoolCreation;
exports.addLiquidity = addLiquidity;
exports.getTokenBalances = getTokenBalances;
const ethers_1 = require("ethers");
const config_1 = require("../config");
const blockchain_1 = require("./blockchain");
// StateView contract for reading pool state (Base mainnet)
const STATE_VIEW_ADDRESS = '0xa3c0c9b65bad0b08107aa264b0f3db444b867a71';
// Position Manager address (Base mainnet)
const POSITION_MANAGER_ADDRESS = '0x7C5f5A4bBd8fD63184577525326123B519429bDc';
// Permit2 address (Base mainnet)
const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3';
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
// Position Manager ABI (for adding liquidity)
const PositionManagerABI = [
    'function modifyLiquidities(bytes unlockData, uint256 deadline) external payable'
];
// Permit2 ABI (for token approvals)
const Permit2ABI = [
    'function approve(address token, address spender, uint160 amount, uint48 expiration) external'
];
// ERC20 ABI (for token approvals)
const ERC20ABI = [
    'function approve(address spender, uint256 amount) external returns (bool)',
    'function balanceOf(address account) external view returns (uint256)',
    'function allowance(address owner, address spender) external view returns (uint256)'
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
// Add Liquidity function (based on working Foundry script)
async function addLiquidity(params) {
    try {
        const wallet = (0, blockchain_1.getBackendWallet)();
        // Fix poolId format - ensure it has 0x prefix
        const formattedPoolId = params.poolId.startsWith('0x') ? params.poolId : `0x${params.poolId}`;
        // Get contract instances
        const positionManager = new ethers_1.ethers.Contract(POSITION_MANAGER_ADDRESS, PositionManagerABI, wallet);
        const permit2 = new ethers_1.ethers.Contract(PERMIT2_ADDRESS, Permit2ABI, wallet);
        const stateView = getStateViewContract();
        console.log(`Adding liquidity to pool ${formattedPoolId} for user ${params.userAddress}`);
        // Ensure correct token order (same as Foundry script)
        let currency0 = params.token0;
        let currency1 = params.token1;
        if (params.token0.toLowerCase() > params.token1.toLowerCase()) {
            currency0 = params.token1;
            currency1 = params.token0;
        }
        // Get current pool state to determine tick range
        const slot0Result = await stateView.getSlot0(formattedPoolId);
        const [sqrtPriceX96, currentTick] = slot0Result;
        console.log(`Current pool state - sqrtPriceX96: ${sqrtPriceX96}, tick: ${currentTick}`);
        // Calculate tick range (wide range like in Foundry script)
        const tickSpacing = params.tickSpacing;
        const tickLower = params.tickLower || Math.floor((Number(currentTick) - (1000 * tickSpacing)) / tickSpacing) * tickSpacing;
        const tickUpper = params.tickUpper || Math.floor((Number(currentTick) + (1000 * tickSpacing)) / tickSpacing) * tickSpacing;
        console.log(`Tick range - Lower: ${tickLower}, Upper: ${tickUpper}`);
        // Calculate liquidity (simplified - using token amounts directly)
        const amount0 = ethers_1.ethers.parseEther(params.amount0);
        const amount1 = ethers_1.ethers.parseEther(params.amount1);
        // Slippage protection (1% extra like in Foundry)
        const amount0Max = amount0 + (amount0 / 100n);
        const amount1Max = amount1 + (amount1 / 100n);
        // Create pool key
        const poolKey = {
            currency0,
            currency1,
            fee: params.fee,
            tickSpacing: params.tickSpacing,
            hooks: params.hookAddress
        };
        // Step 1: Approve tokens to Permit2 (like in Foundry script)
        console.log('Approving tokens to Permit2...');
        const token0Contract = new ethers_1.ethers.Contract(currency0, ERC20ABI, wallet);
        const token1Contract = new ethers_1.ethers.Contract(currency1, ERC20ABI, wallet);
        const tx1 = await token0Contract.approve(PERMIT2_ADDRESS, ethers_1.ethers.MaxUint256);
        await tx1.wait();
        const tx2 = await token1Contract.approve(PERMIT2_ADDRESS, ethers_1.ethers.MaxUint256);
        await tx2.wait();
        // Step 2: Give Permit2 permission (like in Foundry script)
        console.log('Setting Permit2 allowances...');
        const maxUint160 = '1461501637330902918203684832716283019655932542975'; // 2^160 - 1
        const maxUint48 = '281474976710655'; // 2^48 - 1
        const tx3 = await permit2.approve(currency0, POSITION_MANAGER_ADDRESS, maxUint160, maxUint48);
        await tx3.wait();
        const tx4 = await permit2.approve(currency1, POSITION_MANAGER_ADDRESS, maxUint160, maxUint48);
        await tx4.wait();
        // Step 3: Encode Actions (following Foundry script pattern)
        const MINT_POSITION = 0x0d;
        const SETTLE_PAIR = 0x02;
        const actions = ethers_1.ethers.solidityPacked(['uint8', 'uint8'], [MINT_POSITION, SETTLE_PAIR]);
        // Step 4: Encode Parameters (following Foundry script)
        const hookData = ethers_1.ethers.AbiCoder.defaultAbiCoder().encode(['address'], [params.userAddress]);
        // Calculate approximate liquidity (simplified)
        const liquidity = ethers_1.ethers.parseEther('1000000'); // 1M liquidity units as example
        // Parameters for MINT_POSITION
        const mintParams = ethers_1.ethers.AbiCoder.defaultAbiCoder().encode(['tuple(address,address,uint24,int24,address)', 'int24', 'int24', 'uint256', 'uint128', 'uint128', 'address', 'bytes'], [
            [poolKey.currency0, poolKey.currency1, poolKey.fee, poolKey.tickSpacing, poolKey.hooks],
            tickLower,
            tickUpper,
            liquidity,
            amount0Max,
            amount1Max,
            params.userAddress,
            hookData
        ]);
        // Parameters for SETTLE_PAIR
        const settleParams = ethers_1.ethers.AbiCoder.defaultAbiCoder().encode(['address', 'address'], [currency0, currency1]);
        // Combine parameters
        const allParams = ethers_1.ethers.AbiCoder.defaultAbiCoder().encode(['bytes', 'bytes[]'], [actions, [mintParams, settleParams]]);
        // Step 5: Execute the mint operation
        const deadline = Math.floor(Date.now() / 1000) + 120; // 2 minutes from now
        console.log('Executing mint position...');
        const tx = await positionManager.modifyLiquidities(allParams, deadline);
        console.log(`Transaction sent: ${tx.hash}`);
        const receipt = await tx.wait();
        console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
        return {
            success: true,
            message: 'Liquidity added successfully',
            data: {
                poolId: formattedPoolId,
                userAddress: params.userAddress,
                amount0: params.amount0,
                amount1: params.amount1,
                tickLower,
                tickUpper,
                transactionHash: tx.hash,
                blockNumber: receipt.blockNumber
            }
        };
    }
    catch (error) {
        console.error('Error adding liquidity:', error);
        let message = 'Failed to add liquidity';
        if (error.message.includes('revert')) {
            message = `Contract error: ${error.message}`;
        }
        else if (error.code === 'INSUFFICIENT_FUNDS') {
            message = 'Insufficient funds for transaction';
        }
        return {
            success: false,
            message
        };
    }
}
// Get token balances for a user
async function getTokenBalances(userAddress, tokens) {
    try {
        const provider = (0, blockchain_1.getProvider)();
        const balances = {};
        console.log(`Getting token balances for user: ${userAddress}`);
        for (const tokenAddress of tokens) {
            try {
                const tokenContract = new ethers_1.ethers.Contract(tokenAddress, ERC20ABI, provider);
                const balance = await tokenContract.balanceOf(userAddress);
                balances[tokenAddress] = ethers_1.ethers.formatEther(balance);
                console.log(`Token ${tokenAddress} balance: ${balances[tokenAddress]}`);
            }
            catch (error) {
                console.error(`Error getting balance for token ${tokenAddress}:`, error);
                balances[tokenAddress] = '0';
            }
        }
        return {
            success: true,
            message: 'Token balances retrieved successfully',
            data: {
                userAddress,
                balances
            }
        };
    }
    catch (error) {
        console.error('Error getting token balances:', error);
        return {
            success: false,
            message: 'Failed to get token balances'
        };
    }
}
