import { useState, useEffect } from 'react';
import { Trophy, TrendingUp, Users, DollarSign, Loader, RefreshCw } from 'lucide-react';
import { apiService } from '@/services/api';
import type { EpochInfo, KolRanking } from '@/types';
import toast from 'react-hot-toast';

export function Leaderboard() {
  const [leaderboard, setLeaderboard] = useState<KolRanking[]>([]);
  const [epochInfo, setEpochInfo] = useState<EpochInfo['data'] | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const fetchData = async () => {
    try {
      const [leaderboardRes, epochRes] = await Promise.all([
        apiService.getLeaderboard(),
        apiService.getCurrentEpoch()
      ]);
      
      if (leaderboardRes.success) {
        setLeaderboard(leaderboardRes.data.rankings);
      }
      
      if (epochRes.success) {
        setEpochInfo(epochRes.data);
      }
    } catch (error) {
      console.error('Error fetching leaderboard data:', error);
      toast.error('Failed to load leaderboard data');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  const handleRefresh = async () => {
    setRefreshing(true);
    await fetchData();
  };

  useEffect(() => {
    fetchData();
  }, []);

  const formatTvl = (tvl: string) => {
    const num = parseFloat(tvl);
    if (num >= 1000000) {
      return `$${(num / 1000000).toFixed(1)}M`;
    } else if (num >= 1000) {
      return `$${(num / 1000).toFixed(1)}K`;
    }
    return `$${num.toFixed(2)}`;
  };

  const getRankIcon = (rank: number) => {
    if (rank === 1) return '🥇';
    if (rank === 2) return '🥈';
    if (rank === 3) return '🥉';
    return `#${rank}`;
  };

  if (loading) {
    return (
      <div className="space-y-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Leaderboard</h1>
          <p className="text-gray-600 mt-2">KOL rankings and performance metrics.</p>
        </div>
        <div className="flex justify-center items-center py-12">
          <Loader className="w-8 h-8 animate-spin text-blue-600" />
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Leaderboard</h1>
          <p className="text-gray-600 mt-2">KOL rankings and performance metrics.</p>
        </div>
        <button
          onClick={handleRefresh}
          disabled={refreshing}
          className="btn-primary flex items-center gap-2"
        >
          <RefreshCw className={`w-4 h-4 ${refreshing ? 'animate-spin' : ''}`} />
          Refresh
        </button>
      </div>

      {/* Epoch Info */}
      {epochInfo && (
        <div className="card bg-gradient-to-r from-blue-50 to-purple-50 border-blue-200">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-lg font-semibold text-gray-900 mb-2">Current Epoch</h3>
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="text-gray-600">Epoch #</span>
                  <span className="font-semibold ml-2">{epochInfo.currentEpoch}</span>
                </div>
                <div>
                  <span className="text-gray-600">Status</span>
                  <span className={`ml-2 px-2 py-1 rounded-full text-xs font-medium ${
                    epochInfo.isActive 
                      ? 'bg-green-100 text-green-800' 
                      : 'bg-gray-100 text-gray-800'
                  }`}>
                    {epochInfo.isActive ? 'Active' : 'Inactive'}
                  </span>
                </div>
              </div>
            </div>
            <Trophy className="w-12 h-12 text-yellow-500" />
          </div>
        </div>
      )}

      {/* Stats Overview */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="card">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-gray-600 text-sm">Total KOLs</p>
              <p className="text-2xl font-bold text-gray-900">{leaderboard.length}</p>
            </div>
            <Users className="w-8 h-8 text-blue-600" />
          </div>
        </div>
        
        <div className="card">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-gray-600 text-sm">Total TVL</p>
              <p className="text-2xl font-bold text-gray-900">
                {formatTvl(leaderboard.reduce((sum, kol) => sum + parseFloat(kol.totalTvl), 0).toString())}
              </p>
            </div>
            <DollarSign className="w-8 h-8 text-green-600" />
          </div>
        </div>
        
        <div className="card">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-gray-600 text-sm">Total Referrals</p>
              <p className="text-2xl font-bold text-gray-900">
                {leaderboard.reduce((sum, kol) => sum + kol.referralCount, 0)}
              </p>
            </div>
            <TrendingUp className="w-8 h-8 text-purple-600" />
          </div>
        </div>
      </div>

      {/* Leaderboard Table */}
      <div className="card">
        <div className="mb-6">
          <h3 className="text-lg font-semibold text-gray-900">KOL Rankings</h3>
          <p className="text-gray-600 text-sm">Ranked by total TVL generated through referrals</p>
        </div>
        
        {leaderboard.length === 0 ? (
          <div className="text-center py-12">
            <Trophy className="w-12 h-12 text-gray-400 mx-auto mb-4" />
            <p className="text-gray-600">No KOLs registered yet</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-200">
                  <th className="text-left py-3 px-4 font-semibold text-gray-900">Rank</th>
                  <th className="text-left py-3 px-4 font-semibold text-gray-900">KOL</th>
                  <th className="text-left py-3 px-4 font-semibold text-gray-900">Referral Code</th>
                  <th className="text-left py-3 px-4 font-semibold text-gray-900">TVL</th>
                  <th className="text-left py-3 px-4 font-semibold text-gray-900">Referrals</th>
                  <th className="text-left py-3 px-4 font-semibold text-gray-900">Points</th>
                </tr>
              </thead>
              <tbody>
                {leaderboard.map((kol) => (
                  <tr key={kol.kolAddress} className="border-b border-gray-100 hover:bg-gray-50">
                    <td className="py-4 px-4">
                      <span className="text-2xl">{getRankIcon(kol.rank)}</span>
                    </td>
                    <td className="py-4 px-4">
                      <div className="font-mono text-sm">
                        {kol.kolAddress.slice(0, 6)}...{kol.kolAddress.slice(-4)}
                      </div>
                    </td>
                    <td className="py-4 px-4">
                      <span className="px-2 py-1 bg-blue-100 text-blue-800 rounded-full text-sm font-medium">
                        {kol.referralCode}
                      </span>
                    </td>
                    <td className="py-4 px-4">
                      <span className="font-semibold text-green-600">
                        {formatTvl(kol.totalTvl)}
                      </span>
                    </td>
                    <td className="py-4 px-4">
                      <span className="font-semibold">{kol.referralCount}</span>
                    </td>
                    <td className="py-4 px-4">
                      <span className="font-semibold text-purple-600">
                        {parseFloat(kol.points).toLocaleString()}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
} 