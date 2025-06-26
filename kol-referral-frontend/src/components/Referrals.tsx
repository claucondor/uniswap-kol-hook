import { useState } from 'react';
import { UserPlus, Trophy, Copy, CheckCircle, Loader, RefreshCw, Wallet } from 'lucide-react';
import { apiService } from '@/services/api';
import { useWeb3 } from '@/hooks/useWeb3';
import type { KolRegisterRequest, UserReferralRequest, ReferralCodeInfo } from '@/types';
import toast from 'react-hot-toast';

export function Referrals() {
  const [activeTab, setActiveTab] = useState<'register-kol' | 'register-user' | 'lookup'>('register-kol');
  const [loading, setLoading] = useState(false);
  const [lookupLoading, setLookupLoading] = useState(false);

  // Web3 wallet connection
  const { 
    address, 
    isConnected, 
    isConnecting, 
    connectWallet, 
    switchToBaseNetwork,
    network 
  } = useWeb3();
  
  // KOL Registration - now uses connected wallet address
  const [kolData, setKolData] = useState<Omit<KolRegisterRequest, 'kolAddress'> & { kolAddress?: string }>({
    referralCode: '',
    socialHandle: ''
  });
  
  // User Registration - now uses connected wallet address
  const [userData, setUserData] = useState<Omit<UserReferralRequest, 'userAddress'> & { userAddress?: string }>({
    referralCode: ''
  });
  
  // Lookup
  const [lookupCode, setLookupCode] = useState('');
  const [referralInfo, setReferralInfo] = useState<ReferralCodeInfo['data'] | null>(null);

  const handleKolRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!isConnected || !address) {
      toast.error('Please connect your wallet first');
      return;
    }
    
    if (!kolData.referralCode || !kolData.socialHandle) {
      toast.error('Please fill in all fields');
      return;
    }

    // Check if we're on the correct network
    if (network !== 8453) { // Base mainnet
      const switched = await switchToBaseNetwork();
      if (!switched) {
        toast.error('Please switch to Base network');
        return;
      }
    }
    
    setLoading(true);
    try {
      const requestData: KolRegisterRequest = {
        kolAddress: address,
        referralCode: kolData.referralCode,
        socialHandle: kolData.socialHandle
      };
      
      const response = await apiService.registerKol(requestData);
      if (response.success) {
        toast.success('KOL registered successfully!');
        setKolData({ referralCode: '', socialHandle: '' });
      } else {
        toast.error(response.message || 'Failed to register KOL');
      }
    } catch (error: any) {
      console.error('Error registering KOL:', error);
      toast.error(error.response?.data?.message || 'Failed to register KOL');
    } finally {
      setLoading(false);
    }
  };

  const handleUserRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!isConnected || !address) {
      toast.error('Please connect your wallet first');
      return;
    }
    
    if (!userData.referralCode) {
      toast.error('Please enter a referral code');
      return;
    }

    // Check if we're on the correct network
    if (network !== 8453) { // Base mainnet
      const switched = await switchToBaseNetwork();
      if (!switched) {
        toast.error('Please switch to Base network');
        return;
      }
    }
    
    setLoading(true);
    try {
      const requestData: UserReferralRequest = {
        userAddress: address,
        referralCode: userData.referralCode
      };
      
      const response = await apiService.registerUserReferral(requestData);
      if (response.success) {
        toast.success('User registered with referral successfully!');
        setUserData({ referralCode: '' });
      } else {
        toast.error(response.message || 'Failed to register user');
      }
    } catch (error: any) {
      console.error('Error registering user:', error);
      toast.error(error.response?.data?.message || 'Failed to register user');
    } finally {
      setLoading(false);
    }
  };

  const handleLookupCode = async () => {
    if (!lookupCode.trim()) {
      toast.error('Please enter a referral code');
      return;
    }
    
    setLookupLoading(true);
    try {
      const response = await apiService.getReferralCodeInfo(lookupCode);
      if (response.success) {
        setReferralInfo(response.data);
      } else {
        toast.error('Referral code not found');
        setReferralInfo(null);
      }
    } catch (error: any) {
      console.error('Error looking up referral code:', error);
      toast.error('Failed to lookup referral code');
      setReferralInfo(null);
    } finally {
      setLookupLoading(false);
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    toast.success('Copied to clipboard!');
  };

  const tabs = [
    { id: 'register-kol', label: 'Register as KOL', icon: Trophy },
    { id: 'register-user', label: 'Register User', icon: UserPlus },
    { id: 'lookup', label: 'Lookup Code', icon: RefreshCw }
  ];

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Referrals</h1>
        <p className="text-gray-600 mt-2">Manage KOL registrations and user referrals.</p>
      </div>

      {/* Wallet Connection Status */}
      {!isConnected && (
        <div className="card bg-yellow-50 border-yellow-200">
          <div className="flex items-center gap-3">
            <Wallet className="w-5 h-5 text-yellow-600" />
            <div className="flex-1">
              <h3 className="text-sm font-medium text-yellow-800">Wallet Required</h3>
              <p className="text-sm text-yellow-700">Connect your wallet to register as KOL or user.</p>
            </div>
            <button
              onClick={connectWallet}
              disabled={isConnecting}
              className="btn-primary text-sm py-2 px-4"
            >
              {isConnecting ? (
                <Loader className="w-4 h-4 animate-spin" />
              ) : (
                'Connect Wallet'
              )}
            </button>
          </div>
        </div>
      )}

      {/* Connected Wallet Info */}
      {isConnected && address && (
        <div className="card bg-green-50 border-green-200">
          <div className="flex items-center gap-3">
            <CheckCircle className="w-5 h-5 text-green-600" />
            <div className="flex-1">
              <h3 className="text-sm font-medium text-green-800">Wallet Connected</h3>
              <p className="text-sm text-green-700 font-mono">
                {address.slice(0, 6)}...{address.slice(-4)}
              </p>
            </div>
            <button
              onClick={() => copyToClipboard(address)}
              className="text-green-600 hover:text-green-700"
            >
              <Copy className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

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

      {/* KOL Registration Tab */}
      {activeTab === 'register-kol' && (
        <div className="card">
          <div className="mb-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Register as KOL</h3>
            <p className="text-gray-600 text-sm">
              Register as a Key Opinion Leader to start earning from referrals. You'll receive an NFT representing your KOL status.
            </p>
          </div>
          
          <form onSubmit={handleKolRegister} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                KOL Address (Connected Wallet)
              </label>
              <div className="input bg-gray-50 text-gray-600 font-mono">
                {isConnected && address ? (
                  address
                ) : (
                  'Please connect your wallet'
                )}
              </div>
              <p className="text-xs text-gray-500 mt-1">
                This will be automatically filled with your connected wallet address
              </p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Referral Code
              </label>
              <input
                type="text"
                value={kolData.referralCode}
                onChange={(e) => setKolData({ ...kolData, referralCode: e.target.value.toUpperCase() })}
                placeholder="KOL123"
                className="input"
                maxLength={20}
                required
                disabled={!isConnected}
              />
              <p className="text-xs text-gray-500 mt-1">
                Choose a unique referral code (3-20 characters)
              </p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Social Handle
              </label>
              <input
                type="text"
                value={kolData.socialHandle}
                onChange={(e) => setKolData({ ...kolData, socialHandle: e.target.value })}
                placeholder="@your_twitter_handle"
                className="input"
                maxLength={50}
                required
                disabled={!isConnected}
              />
              <p className="text-xs text-gray-500 mt-1">
                Your Twitter/X handle or other social media identifier
              </p>
            </div>
            
            <button
              type="submit"
              disabled={loading || !isConnected}
              className="btn-primary w-full flex items-center justify-center gap-2 disabled:opacity-50"
            >
              {loading ? (
                <Loader className="w-4 h-4 animate-spin" />
              ) : (
                <Trophy className="w-4 h-4" />
              )}
              {loading ? 'Registering...' : 'Register as KOL'}
            </button>
          </form>
        </div>
      )}

      {/* User Registration Tab */}
      {activeTab === 'register-user' && (
        <div className="card">
          <div className="mb-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Register User with Referral</h3>
            <p className="text-gray-600 text-sm">
              Register with a KOL's referral code to get started. This allows you to participate in the referral program.
            </p>
          </div>
          
          <form onSubmit={handleUserRegister} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                User Address (Connected Wallet)
              </label>
              <div className="input bg-gray-50 text-gray-600 font-mono">
                {isConnected && address ? (
                  address
                ) : (
                  'Please connect your wallet'
                )}
              </div>
              <p className="text-xs text-gray-500 mt-1">
                This will be automatically filled with your connected wallet address
              </p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Referral Code
              </label>
              <input
                type="text"
                value={userData.referralCode}
                onChange={(e) => setUserData({ ...userData, referralCode: e.target.value.toUpperCase() })}
                placeholder="Enter KOL's referral code"
                className="input"
                maxLength={20}
                required
                disabled={!isConnected}
              />
              <p className="text-xs text-gray-500 mt-1">
                Enter the referral code provided by a KOL
              </p>
            </div>
            
            <button
              type="submit"
              disabled={loading || !isConnected}
              className="btn-primary w-full flex items-center justify-center gap-2 disabled:opacity-50"
            >
              {loading ? (
                <Loader className="w-4 h-4 animate-spin" />
              ) : (
                <UserPlus className="w-4 h-4" />
              )}
              {loading ? 'Registering...' : 'Register with Referral'}
            </button>
          </form>
        </div>
      )}

      {/* Lookup Tab */}
      {activeTab === 'lookup' && (
        <div className="card">
          <div className="mb-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Lookup Referral Code</h3>
            <p className="text-gray-600 text-sm">
              Search for information about a specific referral code.
            </p>
          </div>
          
          <div className="space-y-4">
            <div className="flex gap-2">
              <input
                type="text"
                value={lookupCode}
                onChange={(e) => setLookupCode(e.target.value.toUpperCase())}
                placeholder="Enter referral code..."
                className="input flex-1"
                onKeyPress={(e) => e.key === 'Enter' && handleLookupCode()}
              />
              <button
                onClick={handleLookupCode}
                disabled={lookupLoading}
                className="btn-primary flex items-center gap-2"
              >
                {lookupLoading ? (
                  <Loader className="w-4 h-4 animate-spin" />
                ) : (
                  <RefreshCw className="w-4 h-4" />
                )}
                Lookup
              </button>
            </div>
            
            {referralInfo && (
              <div className="mt-6 p-4 bg-gray-50 rounded-lg">
                <div className="flex items-center gap-2 mb-4">
                  <CheckCircle className="w-5 h-5 text-green-600" />
                  <h4 className="font-semibold text-gray-900">Referral Code Found</h4>
                </div>
                
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                  <div>
                    <span className="text-gray-600">Code:</span>
                    <div className="flex items-center gap-2 mt-1">
                      <span className="font-semibold">{referralInfo.referralCode}</span>
                      <button
                        onClick={() => copyToClipboard(referralInfo.referralCode)}
                        className="text-blue-600 hover:text-blue-700"
                      >
                        <Copy className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                  
                  <div>
                    <span className="text-gray-600">KOL Address:</span>
                    <div className="flex items-center gap-2 mt-1">
                      <span className="font-mono text-xs">{referralInfo.kolAddress}</span>
                      <button
                        onClick={() => copyToClipboard(referralInfo.kolAddress)}
                        className="text-blue-600 hover:text-blue-700"
                      >
                        <Copy className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                  
                  <div>
                    <span className="text-gray-600">Status:</span>
                    <span className={`ml-2 px-2 py-1 rounded-full text-xs font-medium ${
                      referralInfo.isActive 
                        ? 'bg-green-100 text-green-800' 
                        : 'bg-red-100 text-red-800'
                    }`}>
                      {referralInfo.isActive ? 'Active' : 'Inactive'}
                    </span>
                  </div>
                  
                  <div>
                    <span className="text-gray-600">Registered Users:</span>
                    <span className="font-semibold ml-2 text-blue-600">{referralInfo.totalReferrals || '0'}</span>
                  </div>
                  
                  <div>
                    <span className="text-gray-600">Active in Pools:</span>
                    <span className="font-semibold ml-2 text-purple-600">{referralInfo.uniqueUsers || '0'}</span>
                  </div>
                  
                  <div>
                    <span className="text-gray-600">Total TVL:</span>
                    <span className="font-semibold ml-2 text-green-600">
                      ${parseFloat(referralInfo.totalTVL || '0').toLocaleString()}
                    </span>
                  </div>
                  
                  {referralInfo.referredUsers && referralInfo.referredUsers.length > 0 && (
                    <div className="md:col-span-2">
                      <span className="text-gray-600">Referred Users:</span>
                      <div className="mt-2 space-y-1">
                        {referralInfo.referredUsers.map((user: string, index: number) => (
                          <div key={index} className="flex items-center gap-2">
                            <span className="font-mono text-xs text-gray-700">
                              {user.slice(0, 6)}...{user.slice(-4)}
                            </span>
                            <button
                              onClick={() => copyToClipboard(user)}
                              className="text-blue-600 hover:text-blue-700"
                            >
                              <Copy className="w-3 h-3" />
                            </button>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
} 