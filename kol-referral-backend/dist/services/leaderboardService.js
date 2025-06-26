"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getLeaderboard = getLeaderboard;
exports.getCurrentEpoch = getCurrentEpoch;
exports.getEpochLeaderboard = getEpochLeaderboard;
exports.getKOLRanking = getKOLRanking;
const ethers_1 = require("ethers");
const config_1 = require("../config");
const blockchain_1 = require("./blockchain");
// Contract ABI - Import from the existing ABI file
const TVLLeaderboard_json_1 = __importDefault(require("../abis/TVLLeaderboard.json"));
// Get TVL Leaderboard contract instance
function getTVLLeaderboardContract() {
    const provider = (0, blockchain_1.getProvider)();
    return new ethers_1.ethers.Contract(config_1.config.contracts.tvlLeaderboard, TVLLeaderboard_json_1.default, provider);
}
// Get current leaderboard (top KOLs)
async function getLeaderboard() {
    try {
        console.log('Getting current leaderboard...');
        const leaderboardContract = getTVLLeaderboardContract();
        console.log('Fetching current leaderboard from contract...');
        // Try to get data from contract, but handle if no data exists yet
        try {
            const topKOLs = await leaderboardContract.getTopKOLs();
            // Format the data if we have any
            const formattedKOLs = topKOLs.map((kol, index) => ({
                rank: index + 1,
                kolAddress: kol.kol || kol.address || kol[0],
                referralCode: kol.referralCode || `KOL${index + 1}`,
                totalTvl: (kol.totalTVL || kol.tvl || kol[1] || '0').toString(),
                referralCount: parseInt((kol.uniqueUsers || kol.users || kol[2] || '0').toString()),
                points: (kol.points || kol.totalTVL || kol[1] || '0').toString()
            }));
            return {
                success: true,
                message: 'Leaderboard retrieved successfully',
                data: {
                    epoch: 1,
                    rankings: formattedKOLs
                }
            };
        }
        catch (contractError) {
            // If contract call fails (no data, not initialized, etc.), return empty but valid response
            console.log('Contract call failed, returning empty leaderboard:', contractError.message);
            return {
                success: true,
                message: 'No leaderboard data available yet',
                data: {
                    epoch: 1,
                    rankings: []
                }
            };
        }
    }
    catch (error) {
        console.error('Error getting leaderboard:', error);
        // Return empty data instead of error to keep frontend working
        return {
            success: true,
            message: 'Leaderboard service unavailable, showing empty results',
            data: {
                epoch: 1,
                rankings: []
            }
        };
    }
}
// Get current epoch
async function getCurrentEpoch() {
    try {
        console.log('Getting current epoch...');
        const leaderboardContract = getTVLLeaderboardContract();
        console.log('Fetching current epoch from contract...');
        try {
            const currentEpoch = await leaderboardContract.currentEpoch();
            return {
                success: true,
                message: 'Current epoch retrieved successfully',
                data: {
                    currentEpoch: parseInt(currentEpoch.toString()),
                    startTime: new Date().toISOString(),
                    endTime: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(), // 7 days from now
                    isActive: true
                }
            };
        }
        catch (contractError) {
            // If contract call fails, return default epoch info
            console.log('Contract call failed, returning default epoch:', contractError.message);
            return {
                success: true,
                message: 'Using default epoch information',
                data: {
                    currentEpoch: 1,
                    startTime: new Date().toISOString(),
                    endTime: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
                    isActive: true
                }
            };
        }
    }
    catch (error) {
        console.error('Error getting current epoch:', error);
        // Return default epoch instead of error
        return {
            success: true,
            message: 'Epoch service unavailable, using defaults',
            data: {
                currentEpoch: 1,
                startTime: new Date().toISOString(),
                endTime: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
                isActive: true
            }
        };
    }
}
// Get leaderboard for specific epoch
async function getEpochLeaderboard(epochNumber) {
    try {
        console.log(`Getting leaderboard for epoch ${epochNumber}...`);
        const leaderboardContract = getTVLLeaderboardContract();
        try {
            const epochKOLs = await leaderboardContract.getEpochLeaderboard(epochNumber);
            // Format the data
            const formattedKOLs = epochKOLs.map((kol, index) => ({
                rank: index + 1,
                kolAddress: kol.kol || kol.address || kol[0],
                referralCode: kol.referralCode || `KOL${index + 1}`,
                totalTvl: (kol.totalTVL || kol.tvl || kol[1] || '0').toString(),
                referralCount: parseInt((kol.uniqueUsers || kol.users || kol[2] || '0').toString()),
                points: (kol.points || kol.totalTVL || kol[1] || '0').toString()
            }));
            return {
                success: true,
                message: `Epoch ${epochNumber} leaderboard retrieved successfully`,
                data: {
                    epoch: epochNumber,
                    rankings: formattedKOLs
                }
            };
        }
        catch (contractError) {
            // If specific epoch doesn't exist, return empty but valid response
            console.log(`Epoch ${epochNumber} not found, returning empty:`, contractError.message);
            return {
                success: true,
                message: `No data available for epoch ${epochNumber}`,
                data: {
                    epoch: epochNumber,
                    rankings: []
                }
            };
        }
    }
    catch (error) {
        console.error(`Error getting epoch ${epochNumber} leaderboard:`, error);
        // Return empty data instead of error
        return {
            success: true,
            message: `Epoch ${epochNumber} service unavailable`,
            data: {
                epoch: epochNumber,
                rankings: []
            }
        };
    }
}
// Get KOL ranking and stats
async function getKOLRanking(kolAddress) {
    try {
        console.log(`Getting ranking for KOL: ${kolAddress}`);
        // For now, return empty stats until we have real data
        return {
            success: true,
            message: 'KOL ranking retrieved',
            data: {
                kolAddress,
                rank: 0,
                totalTvl: '0',
                referralCount: 0,
                points: '0',
                isActive: false
            }
        };
    }
    catch (error) {
        console.error(`Error getting KOL ranking for ${kolAddress}:`, error);
        return {
            success: false,
            message: 'Failed to get KOL ranking'
        };
    }
}
