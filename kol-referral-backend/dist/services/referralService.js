"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.registerKOL = registerKOL;
exports.registerReferredUser = registerReferredUser;
exports.getReferralInfo = getReferralInfo;
exports.getKOLStats = getKOLStats;
const ethers_1 = require("ethers");
const config_1 = require("../config");
const blockchain_1 = require("./blockchain");
// Contract ABIs - Import from the existing ABI files
const ReferralRegistry_json_1 = __importDefault(require("../abis/ReferralRegistry.json"));
const ReferralHook_json_1 = __importDefault(require("../abis/ReferralHook.json"));
const TVLLeaderboard_json_1 = __importDefault(require("../abis/TVLLeaderboard.json"));
// Get contract instances
function getReferralRegistryContract() {
    const provider = (0, blockchain_1.getProvider)();
    return new ethers_1.ethers.Contract(config_1.config.contracts.referralRegistry, ReferralRegistry_json_1.default, provider);
}
function getReferralHookContract() {
    const provider = (0, blockchain_1.getProvider)();
    return new ethers_1.ethers.Contract(config_1.config.contracts.referralHookV2, ReferralHook_json_1.default, provider);
}
function getTVLLeaderboardContract() {
    const provider = (0, blockchain_1.getProvider)();
    return new ethers_1.ethers.Contract(config_1.config.contracts.tvlLeaderboard, TVLLeaderboard_json_1.default, provider);
}
// Register a new KOL
async function registerKOL(kolAddress, referralCode, socialHandle, metadataUri) {
    try {
        const wallet = (0, blockchain_1.getBackendWallet)();
        const registryContract = getReferralRegistryContract().connect(wallet);
        console.log(`Registering KOL ${kolAddress} with code ${referralCode}`);
        // Check if code already exists
        try {
            const existingReferral = await registryContract.getReferralByCode(referralCode);
            if (existingReferral.tokenId > 0) {
                return {
                    success: false,
                    message: `Referral code '${referralCode}' already exists`
                };
            }
        }
        catch (error) {
            // Code doesn't exist, continue with registration
        }
        // Mint referral NFT
        const tx = await registryContract.mintReferral(kolAddress, referralCode, socialHandle, metadataUri || `ipfs://kol_${referralCode.toLowerCase()}_metadata`);
        console.log(`Transaction sent: ${tx.hash}`);
        const receipt = await tx.wait();
        console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
        // Get the token ID from the event
        const event = receipt.logs.find((log) => {
            try {
                const parsed = registryContract.interface.parseLog(log);
                return parsed?.name === 'ReferralMinted';
            }
            catch {
                return false;
            }
        });
        let tokenId = 0;
        if (event) {
            const parsed = registryContract.interface.parseLog(event);
            tokenId = parsed?.args?.tokenId?.toString() || '0';
        }
        return {
            success: true,
            message: 'KOL registered successfully',
            data: {
                kolAddress,
                referralCode,
                socialHandle,
                tokenId,
                transactionHash: tx.hash,
                blockNumber: receipt.blockNumber
            }
        };
    }
    catch (error) {
        console.error('Error registering KOL:', error);
        let message = 'Failed to register KOL';
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
// Register a referred user
async function registerReferredUser(userAddress, referralCode) {
    try {
        const wallet = (0, blockchain_1.getBackendWallet)();
        const registryContract = getReferralRegistryContract().connect(wallet);
        console.log(`Registering referred user ${userAddress} with code ${referralCode}`);
        // Check if referral code exists
        const existingReferral = await registryContract.getReferralByCode(referralCode);
        if (existingReferral.tokenId === 0) {
            return {
                success: false,
                message: `Referral code '${referralCode}' does not exist`
            };
        }
        // Check if user is already registered
        try {
            const userInfo = await registryContract.getUserReferralInfo(userAddress);
            if (userInfo.tokenId > 0) {
                return {
                    success: false,
                    message: 'User is already registered with a referral code'
                };
            }
        }
        catch (error) {
            // User not registered, continue
        }
        // Register user with referral code
        const tx = await registryContract.setUserReferral(userAddress, referralCode);
        console.log(`Transaction sent: ${tx.hash}`);
        const receipt = await tx.wait();
        console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
        return {
            success: true,
            message: 'User registered with referral code successfully',
            data: {
                userAddress,
                referralCode,
                kolAddress: existingReferral.kol,
                tokenId: existingReferral.tokenId.toString(),
                transactionHash: tx.hash,
                blockNumber: receipt.blockNumber
            }
        };
    }
    catch (error) {
        console.error('Error registering referred user:', error);
        let message = 'Failed to register referred user';
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
// Get referral info by code or user address
async function getReferralInfo(identifier, isUserAddress = false) {
    try {
        const registryContract = getReferralRegistryContract();
        if (isUserAddress) {
            // Get user referral info
            const userInfo = await registryContract.getUserReferralInfo(identifier);
            if (userInfo.tokenId === 0) {
                return {
                    success: false,
                    message: 'User not found or not registered with any referral code'
                };
            }
            return {
                success: true,
                message: 'User referral info retrieved successfully',
                data: {
                    userAddress: identifier,
                    tokenId: userInfo.tokenId.toString(),
                    kolAddress: userInfo.kol,
                    referralCode: userInfo.code
                }
            };
        }
        else {
            // Get referral by code - HYBRID APPROACH
            console.log(`Getting referral info for code: ${identifier}`);
            try {
                // Step 1: Check if the referral code exists using a simple call
                const provider = registryContract.runner?.provider;
                if (!provider) {
                    throw new Error('No provider available');
                }
                // Use low-level call to get just the tokenId (first element)
                const calldata = registryContract.interface.encodeFunctionData('getReferralByCode', [identifier]);
                const result = await provider.call({
                    to: await registryContract.getAddress(),
                    data: calldata
                });
                // Only decode the tokenId part to avoid the corrupted data
                const decodedResult = registryContract.interface.decodeFunctionResult('getReferralByCode', result);
                const tokenId = decodedResult[0];
                console.log(`TokenId from registry:`, tokenId);
                if (tokenId === 0n) {
                    return {
                        success: false,
                        message: `Referral code '${identifier}' not found`
                    };
                }
                // Step 2: Get the KOL address from the NFT owner
                let kolAddress = '0x0000000000000000000000000000000000000000';
                try {
                    // Try to get the owner of the NFT (this should work)
                    kolAddress = await registryContract.ownerOf(tokenId);
                    console.log(`KOL address from NFT owner:`, kolAddress);
                }
                catch (ownerError) {
                    console.warn('Could not get NFT owner:', ownerError);
                }
                // Step 3: Get actual stats from the hook contract (which works correctly)
                let totalTVL = '0';
                let uniqueUsers = '0';
                if (kolAddress !== '0x0000000000000000000000000000000000000000') {
                    try {
                        const hookContract = getReferralHookContract();
                        const stats = await hookContract.getKOLStats(kolAddress);
                        totalTVL = stats.totalTVL.toString();
                        uniqueUsers = stats.uniqueUsers.toString();
                        console.log(`Stats from hook - TVL: ${totalTVL}, Users: ${uniqueUsers}`);
                    }
                    catch (hookError) {
                        console.warn('Could not get stats from hook:', hookError);
                    }
                }
                // Step 4: Get referred users count from events
                let referredUsersCount = '0';
                let referredUsers = [];
                try {
                    const provider = registryContract.runner?.provider;
                    if (provider) {
                        // Query UserReferred events for this KOL
                        const filter = registryContract.filters.UserReferred(null, tokenId, kolAddress);
                        const events = await registryContract.queryFilter(filter);
                        referredUsers = events.map((event) => event.args?.user || '').filter(Boolean);
                        referredUsersCount = referredUsers.length.toString();
                        console.log(`Found ${referredUsersCount} referred users from events`);
                    }
                }
                catch (eventError) {
                    console.warn('Could not get referred users from events:', eventError);
                }
                // Step 5: Try to get social handle from the full referral data
                let socialHandle = 'N/A';
                try {
                    // Try to get the full referral info to extract social handle
                    const fullResult = await registryContract.getReferralByCode(identifier);
                    if (fullResult && fullResult[1] && fullResult[1].socialHandle) {
                        socialHandle = fullResult[1].socialHandle;
                    }
                }
                catch (socialError) {
                    console.warn('Could not get social handle:', socialError);
                    socialHandle = 'KOL_USER'; // Default value
                }
                return {
                    success: true,
                    message: 'Referral info retrieved successfully',
                    data: {
                        tokenId: tokenId.toString(),
                        kolAddress: kolAddress,
                        referralCode: identifier,
                        socialHandle: socialHandle,
                        totalTVL: totalTVL,
                        uniqueUsers: uniqueUsers, // From hook (liquidity activity)
                        totalReferrals: referredUsersCount, // From registry (registered users)
                        referredUsers: referredUsers,
                        isActive: true // Assume active if tokenId exists
                    }
                };
            }
            catch (contractError) {
                console.error('Contract call failed:', contractError);
                return {
                    success: false,
                    message: `Error retrieving referral code '${identifier}': ${contractError.message}`
                };
            }
        }
    }
    catch (error) {
        console.error('Error getting referral info:', error);
        return {
            success: false,
            message: 'Failed to retrieve referral information'
        };
    }
}
// Get KOL stats from hook
async function getKOLStats(kolAddress) {
    try {
        const hookContract = getReferralHookContract();
        console.log(`Getting KOL stats for ${kolAddress}`);
        const stats = await hookContract.getKOLStats(kolAddress);
        return {
            success: true,
            message: 'KOL stats retrieved successfully',
            data: {
                kolAddress,
                totalTVL: stats.totalTVL.toString(),
                uniqueUsers: stats.uniqueUsers.toString()
            }
        };
    }
    catch (error) {
        console.error('Error getting KOL stats:', error);
        return {
            success: false,
            message: 'Failed to retrieve KOL statistics'
        };
    }
}
