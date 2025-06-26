import { useState, useEffect } from 'react';
import { Plus, Droplets, Info, Zap, Loader, Search, Wallet, DollarSign } from 'lucide-react';
import { apiService } from '@/services/api';
import { CONTRACTS } from '@/config/contracts';
import { useWeb3 } from '@/hooks/useWeb3';
import { useLiquidity } from '@/hooks/useLiquidity';
import type { PoolCreateRequest, PoolInfo } from '@/types';
import toast from 'react-hot-toast';

export function Pools() {
  const { address, isConnected, connectWallet } = useWeb3();
  const { addLiquidity, getTokenBalance, isLoading: isAddingLiquidity } = useLiquidity();
  const [activeTab, setActiveTab] = useState<'create' | 'manage' | 'liquidity'>('create');
  const [loading, setLoading] = useState(false);
  const [searchLoading, setSearchLoading] = useState(false);
  const [balancesLoading, setBalancesLoading] = useState(false);
  
  // Pool Creation
  const [poolData, setPoolData] = useState<PoolCreateRequest>({
    token0: CONTRACTS.KOLTEST1,
    token1: CONTRACTS.KOLTEST2,
    fee: 3000,
    tickSpacing: 60,
    hookAddress: CONTRACTS.REFERRAL_HOOK,
    initialPriceX96: '79228162514264337593543950336', // 1:1 price
    userAddress: ''
  });
  
  const [gasEstimate, setGasEstimate] = useState<any>(null);
  
  // Pool Management
  const [searchPoolId, setSearchPoolId] = useState('');
  const [poolInfo, setPoolInfo] = useState<PoolInfo['data'] | null>(null);

  // Token Balances and Add Liquidity
  const [tokenBalances, setTokenBalances] = useState<{ [token: string]: string }>({});
  const [liquidityData, setLiquidityData] = useState({
    poolId: '0x1c580e16c547b863f9bf433ef6d6fe98a533f71d8882b2fb7eca0c3ad7d8e296', // Correct pool ID with 0x prefix
    token0: CONTRACTS.KOLTEST1,
    token1: CONTRACTS.KOLTEST2,
    fee: 3000,
    tickSpacing: 60,
    hookAddress: CONTRACTS.REFERRAL_HOOK,
    amount0: '100',
    amount1: '100'
  });

  // Fetch token balances
  const fetchTokenBalances = async () => {
    if (!isConnected || !address) return;
    
    setBalancesLoading(true);
    try {
      const balance0 = await getTokenBalance(CONTRACTS.KOLTEST1);
      const balance1 = await getTokenBalance(CONTRACTS.KOLTEST2);
      
      setTokenBalances({
        [CONTRACTS.KOLTEST1]: balance0,
        [CONTRACTS.KOLTEST2]: balance1
      });
    } catch (error) {
      console.error('Error fetching token balances:', error);
    } finally {
      setBalancesLoading(false);
    }
  };

  // Add liquidity using the user's wallet
  const handleAddLiquidity = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!isConnected || !address) {
      toast.error('Please connect your wallet first');
      return;
    }
    
    // Validate form data
    if (!liquidityData.poolId || !liquidityData.poolId.trim()) {
      toast.error('Pool ID is required');
      return;
    }
    
    if (!liquidityData.amount0 || parseFloat(liquidityData.amount0) <= 0) {
      toast.error('KOLTEST1 amount must be greater than 0');
      return;
    }
    
    if (!liquidityData.amount1 || parseFloat(liquidityData.amount1) <= 0) {
      toast.error('KOLTEST2 amount must be greater than 0');
      return;
    }
    
    try {
      const result = await addLiquidity({
        token0: liquidityData.token0,
        token1: liquidityData.token1,
        fee: liquidityData.fee,
        tickSpacing: liquidityData.tickSpacing,
        amount0Desired: liquidityData.amount0,
        amount1Desired: liquidityData.amount1
      });
      
      if (result) {
        console.log('Liquidity added successfully:', result);
        // Refresh balances
        fetchTokenBalances();
      }
    } catch (error: any) {
      console.error('Error adding liquidity:', error);
    }
  };

  const handleCreatePool = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!isConnected || !address) {
      toast.error('Please connect your wallet first');
      return;
    }
    
    setLoading(true);
    try {
      const response = await apiService.createPool({
        ...poolData,
        userAddress: address
      });
      if (response.success) {
        toast.success('Pool created successfully!');
        console.log('Pool created:', response.data);
      } else {
        toast.error(response.message || 'Failed to create pool');
      }
    } catch (error: any) {
      console.error('Error creating pool:', error);
      toast.error(error.response?.data?.message || 'Failed to create pool');
    } finally {
      setLoading(false);
    }
  };

  const handleEstimateGas = async () => {
    try {
      const { userAddress, ...estimateData } = poolData;
      const response = await apiService.estimatePoolGas(estimateData);
      if (response.success) {
        setGasEstimate(response.data);
      }
    } catch (error) {
      console.error('Error estimating gas:', error);
    }
  };

  const handleSearchPool = async () => {
    if (!searchPoolId.trim()) {
      toast.error('Please enter a pool ID');
      return;
    }
    
    setSearchLoading(true);
    try {
      const response = await apiService.getPoolInfo(searchPoolId);
      if (response.success) {
        setPoolInfo(response.data);
      } else {
        toast.error('Pool not found');
        setPoolInfo(null);
      }
    } catch (error: any) {
      console.error('Error searching pool:', error);
      toast.error('Failed to find pool');
      setPoolInfo(null);
    } finally {
      setSearchLoading(false);
    }
  };

  useEffect(() => {
    if (activeTab === 'create') {
      handleEstimateGas();
    } else if (activeTab === 'liquidity' && isConnected) {
      fetchTokenBalances();
    }
  }, [poolData.token0, poolData.token1, poolData.fee, poolData.tickSpacing, activeTab, isConnected]);

  const tabs = [
    { id: 'create', label: 'Create Pool', icon: Plus },
    { id: 'manage', label: 'Manage Pools', icon: Droplets },
    { id: 'liquidity', label: 'Add Liquidity', icon: DollarSign }
  ];

  const feeOptions = [
    { value: 500, label: '0.05% (500)', description: 'Best for stable pairs' },
    { value: 3000, label: '0.30% (3000)', description: 'Most common' },
    { value: 10000, label: '1.00% (10000)', description: 'Exotic pairs' }
  ];

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Pools</h1>
        <p className="text-gray-600 mt-2">Create and manage Uniswap V4 liquidity pools with referral hooks.</p>
      </div>

      {/* Tabs */}
      <div className="border-b border-gray-200">
        <nav className="-mb-px flex space-x-8">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as any)}
                className={`py-2 px-1 border-b-2 font-medium text-sm flex items-center gap-2 ${
                  activeTab === tab.id
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                <Icon className="w-4 h-4" />
                {tab.label}
              </button>
            );
          })}
        </nav>
      </div>

      {/* Create Pool Tab */}
      {activeTab === 'create' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="lg:col-span-2">
            <div className="card">
              <div className="mb-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-2">Create New Pool</h3>
                <p className="text-gray-600 text-sm">
                  Create a new Uniswap V4 pool with referral tracking hook.
                </p>
              </div>
              
              <form onSubmit={handleCreatePool} className="space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Token 0 Address
                    </label>
                    <select
                      value={poolData.token0}
                      onChange={(e) => setPoolData({ ...poolData, token0: e.target.value })}
                      className="input"
                    >
                      <option value={CONTRACTS.KOLTEST1}>KOLTEST1</option>
                      <option value={CONTRACTS.KOLTEST2}>KOLTEST2</option>
                    </select>
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Token 1 Address
                    </label>
                    <select
                      value={poolData.token1}
                      onChange={(e) => setPoolData({ ...poolData, token1: e.target.value })}
                      className="input"
                    >
                      <option value={CONTRACTS.KOLTEST2}>KOLTEST2</option>
                      <option value={CONTRACTS.KOLTEST1}>KOLTEST1</option>
                    </select>
                  </div>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Fee Tier
                  </label>
                  <div className="space-y-2">
                    {feeOptions.map((option) => (
                      <label key={option.value} className="flex items-center">
                        <input
                          type="radio"
                          name="fee"
                          value={option.value}
                          checked={poolData.fee === option.value}
                          onChange={(e) => setPoolData({ ...poolData, fee: parseInt(e.target.value) })}
                          className="mr-3"
                        />
                        <div>
                          <span className="font-medium">{option.label}</span>
                          <span className="text-gray-500 text-sm ml-2">{option.description}</span>
                        </div>
                      </label>
                    ))}
                  </div>
                </div>
                
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Tick Spacing
                    </label>
                    <input
                      type="number"
                      value={poolData.tickSpacing}
                      onChange={(e) => setPoolData({ ...poolData, tickSpacing: parseInt(e.target.value) })}
                      className="input"
                      min="1"
                      required
                    />
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Initial Price (sqrtPriceX96)
                    </label>
                    <input
                      type="text"
                      value={poolData.initialPriceX96}
                      onChange={(e) => setPoolData({ ...poolData, initialPriceX96: e.target.value })}
                      className="input"
                      required
                    />
                  </div>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Hook Address
                  </label>
                  <input
                    type="text"
                    value={poolData.hookAddress}
                    onChange={(e) => setPoolData({ ...poolData, hookAddress: e.target.value })}
                    className="input"
                    required
                  />
                  <p className="text-xs text-gray-500 mt-1">
                    Referral tracking hook address
                  </p>
                </div>
                
                {/* Wallet Connection Status */}
                {isConnected ? (
                  <div className="p-3 bg-green-50 border border-green-200 rounded-lg">
                    <div className="flex items-center gap-2">
                      <Wallet className="w-4 h-4 text-green-600" />
                      <span className="text-sm font-medium text-green-900">Wallet Connected</span>
                    </div>
                    <p className="text-xs text-green-700 mt-1 font-mono">
                      {address?.slice(0, 6)}...{address?.slice(-4)}
                    </p>
                  </div>
                ) : (
                  <div className="p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
                    <div className="flex items-center gap-2 mb-2">
                      <Wallet className="w-4 h-4 text-yellow-600" />
                      <span className="text-sm font-medium text-yellow-900">Wallet Required</span>
                    </div>
                    <p className="text-xs text-yellow-700 mb-3">
                      Connect your wallet to create pools
                    </p>
                    <button
                      onClick={connectWallet}
                      className="btn-secondary text-sm w-full"
                    >
                      Connect Wallet
                    </button>
                  </div>
                )}
                
                <button
                  type="submit"
                  disabled={loading || !isConnected}
                  className="btn-primary w-full flex items-center justify-center gap-2 disabled:opacity-50"
                >
                  {loading ? (
                    <Loader className="w-4 h-4 animate-spin" />
                  ) : (
                    <Plus className="w-4 h-4" />
                  )}
                  {loading ? 'Creating Pool...' : 'Create Pool'}
                </button>
              </form>
            </div>
          </div>
          
          {/* Gas Estimation Sidebar */}
          <div className="lg:col-span-1">
            <div className="card">
              <h4 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
                <Zap className="w-4 h-4 text-yellow-500" />
                Gas Estimation
              </h4>
              
              {gasEstimate ? (
                <div className="space-y-3 text-sm">
                  <div>
                    <span className="text-gray-600">Gas Limit:</span>
                    <span className="font-semibold ml-2">{parseInt(gasEstimate.gasLimit).toLocaleString()}</span>
                  </div>
                  <div>
                    <span className="text-gray-600">Gas Price:</span>
                    <span className="font-semibold ml-2">{(parseInt(gasEstimate.gasPrice) / 1e9).toFixed(2)} Gwei</span>
                  </div>
                  <div>
                    <span className="text-gray-600">Estimated Cost:</span>
                    <span className="font-semibold ml-2 text-green-600">{parseFloat(gasEstimate.estimatedCost).toFixed(6)} ETH</span>
                  </div>
                </div>
              ) : (
                <div className="flex items-center justify-center py-4">
                  <Loader className="w-4 h-4 animate-spin text-gray-400" />
                </div>
              )}
              
              <div className="mt-4 p-3 bg-blue-50 rounded-lg">
                <div className="flex items-start gap-2">
                  <Info className="w-4 h-4 text-blue-600 mt-0.5" />
                  <div className="text-xs text-blue-800">
                    <p className="font-medium mb-1">Pool Creation Info</p>
                    <p>Creating a pool will initialize it with the specified parameters and hook address for referral tracking.</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Manage Pools Tab */}
      {activeTab === 'manage' && (
        <div className="space-y-6">
          <div className="card">
            <div className="mb-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-2">Search Pool</h3>
              <p className="text-gray-600 text-sm">
                Enter a pool ID to view pool information and stats.
              </p>
            </div>
            
            <div className="flex gap-2 mb-4">
              <input
                type="text"
                value={searchPoolId}
                onChange={(e) => setSearchPoolId(e.target.value)}
                placeholder="Enter pool ID..."
                className="input flex-1"
                onKeyPress={(e) => e.key === 'Enter' && handleSearchPool()}
              />
              <button
                onClick={handleSearchPool}
                disabled={searchLoading}
                className="btn-primary flex items-center gap-2"
              >
                {searchLoading ? (
                  <Loader className="w-4 h-4 animate-spin" />
                ) : (
                  <Search className="w-4 h-4" />
                )}
                Search
              </button>
            </div>
            
            {poolInfo && (
              <div className="mt-6 p-4 bg-gray-50 rounded-lg">
                <div className="flex items-center gap-2 mb-4">
                  <Droplets className="w-5 h-5 text-blue-600" />
                  <h4 className="font-semibold text-gray-900">Pool Information</h4>
                </div>
                
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                  <div>
                    <span className="text-gray-600">Pool ID:</span>
                    <span className="font-mono text-xs ml-2">{poolInfo.poolId}</span>
                  </div>
                  
                  <div>
                    <span className="text-gray-600">Initialized:</span>
                    <span className={`ml-2 px-2 py-1 rounded-full text-xs font-medium ${
                      poolInfo.isInitialized 
                        ? 'bg-green-100 text-green-800' 
                        : 'bg-red-100 text-red-800'
                    }`}>
                      {poolInfo.isInitialized ? 'Yes' : 'No'}
                    </span>
                  </div>
                  
                  <div>
                    <span className="text-gray-600">Current Tick:</span>
                    <span className="font-semibold ml-2">{poolInfo.tick}</span>
                  </div>
                  
                  <div>
                    <span className="text-gray-600">Liquidity:</span>
                    <span className="font-semibold ml-2">{parseInt(poolInfo.liquidity).toLocaleString()}</span>
                  </div>
                  
                  <div>
                    <span className="text-gray-600">Protocol Fee:</span>
                    <span className="font-semibold ml-2">{poolInfo.protocolFee / 100}%</span>
                  </div>
                  
                  <div>
                    <span className="text-gray-600">LP Fee:</span>
                    <span className="font-semibold ml-2">{poolInfo.lpFee / 100}%</span>
                  </div>
                </div>
                
                <div className="mt-4 pt-4 border-t border-gray-200">
                  <span className="text-gray-600 text-sm">sqrt Price X96:</span>
                  <span className="font-mono text-xs ml-2 break-all">{poolInfo.sqrtPriceX96}</span>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Add Liquidity Tab */}
      {activeTab === 'liquidity' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="lg:col-span-2">
            <div className="card">
              <div className="mb-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-2">Add Liquidity</h3>
                <p className="text-gray-600 text-sm">
                  Add liquidity to an existing pool with referral tracking.
                </p>
              </div>
              
              {isConnected ? (
                <form onSubmit={handleAddLiquidity} className="space-y-6">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Pool ID
                    </label>
                    <input
                      type="text"
                      value={liquidityData.poolId}
                      onChange={(e) => setLiquidityData({ ...liquidityData, poolId: e.target.value })}
                      className="input font-mono text-sm"
                      placeholder="0x1c580e16c547b863f9bf433ef6d6fe98a533f71d8882b2fb7eca0c3ad7d8e296"
                      required
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Your existing KOLTEST1/KOLTEST2 pool ID (must start with 0x)
                    </p>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        KOLTEST1 Amount
                      </label>
                      <input
                        type="number"
                        value={liquidityData.amount0}
                        onChange={(e) => setLiquidityData({ ...liquidityData, amount0: e.target.value })}
                        className="input"
                        min="0"
                        step="0.1"
                        required
                      />
                    </div>
                    
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        KOLTEST2 Amount
                      </label>
                      <input
                        type="number"
                        value={liquidityData.amount1}
                        onChange={(e) => setLiquidityData({ ...liquidityData, amount1: e.target.value })}
                        className="input"
                        min="0"
                        step="0.1"
                        required
                      />
                    </div>
                  </div>

                  <button
                    type="submit"
                    disabled={isAddingLiquidity}
                    className="btn-primary w-full flex items-center justify-center gap-2 disabled:opacity-50"
                  >
                    {isAddingLiquidity ? (
                      <Loader className="w-4 h-4 animate-spin" />
                    ) : (
                      <DollarSign className="w-4 h-4" />
                    )}
                    {isAddingLiquidity ? 'Adding Liquidity...' : 'Add Liquidity'}
                  </button>
                </form>
              ) : (
                <div className="p-6 bg-yellow-50 border border-yellow-200 rounded-lg text-center">
                  <Wallet className="w-8 h-8 text-yellow-600 mx-auto mb-3" />
                  <h4 className="font-medium text-yellow-900 mb-2">Wallet Required</h4>
                  <p className="text-yellow-700 text-sm mb-4">
                    Connect your wallet to add liquidity to pools
                  </p>
                  <button
                    onClick={connectWallet}
                    className="btn-secondary"
                  >
                    Connect Wallet
                  </button>
                </div>
              )}
            </div>
          </div>
          
          {/* Token Balances Sidebar */}
          <div className="lg:col-span-1">
            <div className="card">
              <h4 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
                <Wallet className="w-4 h-4 text-green-500" />
                Your Token Balances
              </h4>
              
              {isConnected ? (
                balancesLoading ? (
                  <div className="flex items-center justify-center py-4">
                    <Loader className="w-4 h-4 animate-spin text-gray-400" />
                  </div>
                ) : (
                  <div className="space-y-3 text-sm">
                    <div className="p-3 bg-blue-50 rounded-lg">
                      <div className="flex justify-between items-center">
                        <span className="font-medium text-blue-900">KOLTEST1</span>
                        <span className="font-semibold text-blue-700">
                          {tokenBalances[CONTRACTS.KOLTEST1] || '0'} tokens
                        </span>
                      </div>
                      <p className="text-xs text-blue-600 mt-1">
                        {CONTRACTS.KOLTEST1.slice(0, 8)}...{CONTRACTS.KOLTEST1.slice(-6)}
                      </p>
                    </div>
                    
                    <div className="p-3 bg-green-50 rounded-lg">
                      <div className="flex justify-between items-center">
                        <span className="font-medium text-green-900">KOLTEST2</span>
                        <span className="font-semibold text-green-700">
                          {tokenBalances[CONTRACTS.KOLTEST2] || '0'} tokens
                        </span>
                      </div>
                      <p className="text-xs text-green-600 mt-1">
                        {CONTRACTS.KOLTEST2.slice(0, 8)}...{CONTRACTS.KOLTEST2.slice(-6)}
                      </p>
                    </div>
                    
                    <button
                      onClick={fetchTokenBalances}
                      className="btn-secondary w-full text-sm"
                      disabled={balancesLoading}
                    >
                      Refresh Balances
                    </button>
                  </div>
                )
              ) : (
                <div className="text-center py-4">
                  <p className="text-gray-500 text-sm">Connect wallet to view balances</p>
                </div>
              )}
              
              <div className="mt-4 p-3 bg-blue-50 rounded-lg">
                <div className="flex items-start gap-2">
                  <Info className="w-4 h-4 text-blue-600 mt-0.5" />
                  <div className="text-xs text-blue-800">
                    <p className="font-medium mb-1">Liquidity Tips</p>
                    <p>Make sure you have sufficient token balances before adding liquidity. The hook will track your referral data.</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
} 