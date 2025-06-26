import { ethers } from 'ethers';
import { config } from '../config';
import { getProvider } from './blockchain';

// Contract ABIs
import TVLLeaderboardABI from '../abis/TVLLeaderboard.json';
import ReferralHookABI from '../abis/ReferralHook.json';

interface ServiceResponse<T = any> {
  success: boolean;
  message: string;
  data?: T;
}

interface KOLRanking {
  rank: number;
  kolAddress: string;
  referralCode: string;
  totalTvl: string;
  referralCount: number;
  points: string;
}

// Get TVL Leaderboard contract instance
function getTVLLeaderboardContract() {
  const provider = getProvider();
  return new ethers.Contract(
    config.contracts.tvlLeaderboard,
    TVLLeaderboardABI,
    provider
  );
}

// Get ReferralHook contract instance
function getReferralHookContract() {
  const provider = getProvider();
  return new ethers.Contract(
    config.contracts.referralHookV2,
    ReferralHookABI,
    provider
  );
}

// Get real KOL data from ReferralHook contract
async function getRealKOLData(): Promise<KOLRanking[]> {
  try {
    const hookContract = getReferralHookContract();
    
    // Known KOL addresses from our system
    const knownKOLs = [
      '0xC166C00d5696afb27Cf07671a85b78a589a20A5c', // Main KOL from deployment
      // Add more KOL addresses as they register
    ];
    
    const kolRankings: KOLRanking[] = [];
    
    for (let i = 0; i < knownKOLs.length; i++) {
      const kolAddress = knownKOLs[i];
      
      try {
        // Get KOL stats from ReferralHook (same as AnalyzeTVLCalculation.s.sol)
        const [totalTVL, uniqueUsers] = await hookContract.getKOLStats(kolAddress);
        
        // Convert to BigInt for ethers v6 compatibility
        const tvlBigInt = BigInt(totalTVL.toString());
        const usersBigInt = BigInt(uniqueUsers.toString());
        
        // Only include KOLs with actual TVL
        if (tvlBigInt > 0n) {
          kolRankings.push({
            rank: kolRankings.length + 1,
            kolAddress: kolAddress,
            referralCode: `KOL${i + 1}`,
            totalTvl: tvlBigInt.toString(),
            referralCount: Number(usersBigInt),
            points: tvlBigInt.toString()
          });
        }
             } catch (kolError: any) {
         console.log(`Could not get stats for KOL ${kolAddress}:`, kolError.message);
      }
    }
    
    // Sort by TVL (descending) - use string comparison for large numbers
    kolRankings.sort((a, b) => {
      const aTvl = parseFloat(a.totalTvl);
      const bTvl = parseFloat(b.totalTvl);
      return bTvl - aTvl;
    });
    
    // Update ranks after sorting
    kolRankings.forEach((kol, index) => {
      kol.rank = index + 1;
    });
    
    return kolRankings;
  } catch (error) {
    console.error('Error getting real KOL data from ReferralHook:', error);
    return [];
  }
}

// Get current leaderboard (top KOLs)
export async function getLeaderboard(): Promise<ServiceResponse> {
  try {
    console.log('Getting current leaderboard...');
    
    // First try to get real data from ReferralHook
    const realKOLData = await getRealKOLData();
    
    if (realKOLData.length > 0) {
      console.log(`Found ${realKOLData.length} KOLs with real TVL data`);
      return {
        success: true,
        message: 'Real leaderboard data retrieved from ReferralHook',
        data: {
          epoch: 1,
          rankings: realKOLData
        }
      };
    }
    
    // Fallback: Try TVLLeaderboard contract
    const leaderboardContract = getTVLLeaderboardContract();
    
    console.log('Fetching current leaderboard from TVLLeaderboard contract...');
    
    try {
      const topKOLs = await leaderboardContract.getTopKOLs();
      
      // Format the data if we have any
      const formattedKOLs: KOLRanking[] = topKOLs.map((kol: any, index: number) => ({
        rank: index + 1,
        kolAddress: kol.kol || kol.address || kol[0],
        referralCode: kol.referralCode || `KOL${index + 1}`,
        totalTvl: (kol.totalTVL || kol.tvl || kol[1] || '0').toString(),
        referralCount: parseInt((kol.uniqueUsers || kol.users || kol[2] || '0').toString()),
        points: (kol.points || kol.totalTVL || kol[1] || '0').toString()
      }));
      
      return {
        success: true,
        message: 'Leaderboard retrieved from TVLLeaderboard contract',
        data: {
          epoch: 1,
          rankings: formattedKOLs
        }
      };
    } catch (contractError: any) {
      console.log('TVLLeaderboard contract call failed:', contractError.message);
      
      // Return empty data - let frontend handle it gracefully
      return {
        success: true,
        message: 'No leaderboard data available yet - waiting for KOL registrations and liquidity',
        data: {
          epoch: 1,
          rankings: []
        }
      };
    }
  } catch (error: any) {
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
export async function getCurrentEpoch(): Promise<ServiceResponse> {
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
    } catch (contractError: any) {
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
  } catch (error: any) {
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
export async function getEpochLeaderboard(epochNumber: number): Promise<ServiceResponse> {
  try {
    console.log(`Getting leaderboard for epoch ${epochNumber}...`);
    
    const leaderboardContract = getTVLLeaderboardContract();
    
    try {
      const epochKOLs = await leaderboardContract.getEpochLeaderboard(epochNumber);
      
      // Format the data
      const formattedKOLs: KOLRanking[] = epochKOLs.map((kol: any, index: number) => ({
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
    } catch (contractError: any) {
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
  } catch (error: any) {
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
export async function getKOLRanking(kolAddress: string): Promise<ServiceResponse> {
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
  } catch (error: any) {
    console.error(`Error getting KOL ranking for ${kolAddress}:`, error);
    
    return {
      success: false,
      message: 'Failed to get KOL ranking'
    };
  }
} 