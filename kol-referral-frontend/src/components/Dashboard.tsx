import { useState, useEffect } from 'react';
import { 
  Users, 
  Trophy, 
  TrendingUp, 
  DollarSign,
  Activity,
  ArrowUpRight,
  ArrowDownRight
} from 'lucide-react';
import { useWeb3 } from '@/hooks/useWeb3';
import { formatAddress, formatTokenAmount } from '@/lib/utils';
import { CONTRACTS } from '@/config/contracts';

interface StatCardProps {
  title: string;
  value: string;
  change?: string;
  changeType?: 'positive' | 'negative' | 'neutral';
  icon: React.ComponentType<{ className?: string }>;
}

function StatCard({ title, value, change, changeType, icon: Icon }: StatCardProps) {
  return (
    <div className="card">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-gray-600">{title}</p>
          <p className="text-2xl font-bold text-gray-900">{value}</p>
          {change && (
            <div className="flex items-center mt-1">
              {changeType === 'positive' ? (
                <ArrowUpRight className="w-4 h-4 text-green-500" />
              ) : changeType === 'negative' ? (
                <ArrowDownRight className="w-4 h-4 text-red-500" />
              ) : (
                <Activity className="w-4 h-4 text-gray-500" />
              )}
              <span className={`text-sm ml-1 ${
                changeType === 'positive' ? 'text-green-600' : 
                changeType === 'negative' ? 'text-red-600' : 'text-gray-600'
              }`}>
                {change}
              </span>
            </div>
          )}
        </div>
        <div className="p-3 bg-primary-50 rounded-lg">
          <Icon className="w-6 h-6 text-primary-600" />
        </div>
      </div>
    </div>
  );
}

export function Dashboard() {
  const { address, isConnected } = useWeb3();
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalTVL: 0n,
    activeKOLs: 0,
    totalReferrals: 0,
  });

  // Mock data - in real app, fetch from contracts
  useEffect(() => {
    setStats({
      totalUsers: 1247,
      totalTVL: 2500000000000000000000000n, // 2.5M tokens
      activeKOLs: 89,
      totalReferrals: 3421,
    });
  }, []);

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-gray-600 mt-2">
          Welcome to the KOL Referral System. Track your performance and manage your referrals.
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title="Total Users"
          value={stats.totalUsers.toLocaleString()}
          change="+12%"
          changeType="positive"
          icon={Users}
        />
        <StatCard
          title="Total TVL"
          value={formatTokenAmount(stats.totalTVL)}
          change="+8.5%"
          changeType="positive"
          icon={DollarSign}
        />
        <StatCard
          title="Active KOLs"
          value={stats.activeKOLs.toString()}
          change="+3"
          changeType="positive"
          icon={Trophy}
        />
        <StatCard
          title="Total Referrals"
          value={stats.totalReferrals.toLocaleString()}
          change="+15%"
          changeType="positive"
          icon={TrendingUp}
        />
      </div>

      {/* Connected Wallet Info */}
      {isConnected && (
        <div className="card">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Your Wallet</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <p className="text-sm text-gray-600">Address</p>
              <p className="font-mono text-sm">{formatAddress(address || '')}</p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Network</p>
              <p className="text-sm">Base Mainnet</p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Status</p>
              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                Connected
              </span>
            </div>
          </div>
        </div>
      )}

      {/* Quick Actions */}
      <div className="card">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <button className="btn-primary">
            Request Test Tokens
          </button>
          <button className="btn-secondary">
            View Leaderboard
          </button>
          <button className="btn-secondary">
            Create Pool
          </button>
        </div>
      </div>

      {/* Contract Addresses */}
      <div className="card">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Contract Addresses</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <p className="text-sm text-gray-600">Referral Registry</p>
            <p className="font-mono text-sm">{formatAddress(CONTRACTS.REFERRAL_REGISTRY)}</p>
          </div>
          <div>
            <p className="text-sm text-gray-600">TVL Leaderboard</p>
            <p className="font-mono text-sm">{formatAddress(CONTRACTS.TVL_LEADERBOARD)}</p>
          </div>
          <div>
            <p className="text-sm text-gray-600">Referral Hook</p>
            <p className="font-mono text-sm">{formatAddress(CONTRACTS.REFERRAL_HOOK)}</p>
          </div>
          <div>
            <p className="text-sm text-gray-600">KOLTEST1 Token</p>
            <p className="font-mono text-sm">{formatAddress(CONTRACTS.KOLTEST1)}</p>
          </div>
        </div>
      </div>
    </div>
  );
} 