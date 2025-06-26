import { useState, useEffect } from 'react';
import { Settings as SettingsIcon, Wallet, ExternalLink, CheckCircle, AlertCircle, Copy } from 'lucide-react';
import { apiService } from '@/services/api';
import { CONTRACTS, NETWORK } from '@/config/contracts';
import type { HealthResponse } from '@/types';
import toast from 'react-hot-toast';

export function Settings() {
  const [walletAddress, setWalletAddress] = useState<string>('');
  const [networkId, setNetworkId] = useState<number | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [systemHealth, setSystemHealth] = useState<HealthResponse | null>(null);

  useEffect(() => {
    checkWalletConnection();
    fetchSystemHealth();
  }, []);

  const checkWalletConnection = async () => {
    if (typeof window !== 'undefined' && window.ethereum) {
      try {
        const accounts = await window.ethereum.request({ method: 'eth_accounts' });
        const network = await window.ethereum.request({ method: 'eth_chainId' });
        
        if (accounts.length > 0) {
          setWalletAddress(accounts[0]);
          setNetworkId(parseInt(network, 16));
          setIsConnected(true);
        }
      } catch (error) {
        console.error('Error checking wallet connection:', error);
      }
    }
  };

  const connectWallet = async () => {
    if (typeof window !== 'undefined' && window.ethereum) {
      try {
        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        const network = await window.ethereum.request({ method: 'eth_chainId' });
        
        setWalletAddress(accounts[0]);
        setNetworkId(parseInt(network, 16));
        setIsConnected(true);
        toast.success('Wallet connected successfully!');
      } catch (error) {
        console.error('Error connecting wallet:', error);
        toast.error('Failed to connect wallet');
      }
    } else {
      toast.error('MetaMask not detected. Please install MetaMask.');
    }
  };

  const switchToBase = async () => {
    if (typeof window !== 'undefined' && window.ethereum) {
      try {
        await window.ethereum.request({
          method: 'wallet_switchEthereumChain',
          params: [{ chainId: `0x${NETWORK.chainId.toString(16)}` }],
        });
        toast.success('Switched to Base network');
      } catch (error: any) {
        if (error.code === 4902) {
          // Network not added, add it
          try {
            await window.ethereum.request({
              method: 'wallet_addEthereumChain',
              params: [{
                chainId: `0x${NETWORK.chainId.toString(16)}`,
                chainName: NETWORK.name,
                nativeCurrency: {
                  name: 'ETH',
                  symbol: 'ETH',
                  decimals: 18,
                },
                rpcUrls: [NETWORK.rpcUrl],
                blockExplorerUrls: [NETWORK.blockExplorer],
              }],
            });
            toast.success('Base network added and switched');
          } catch (addError) {
            console.error('Error adding Base network:', addError);
            toast.error('Failed to add Base network');
          }
        } else {
          console.error('Error switching to Base:', error);
          toast.error('Failed to switch to Base network');
        }
      }
    }
  };

  const fetchSystemHealth = async () => {
    try {
      const health = await apiService.getHealth();
      setSystemHealth(health);
    } catch (error) {
      console.error('Error fetching system health:', error);
    }
  };

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text);
    toast.success(`${label} copied to clipboard!`);
  };

  const isCorrectNetwork = networkId === NETWORK.chainId;

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Settings</h1>
        <p className="text-gray-600 mt-2">Configure your wallet and view system status.</p>
      </div>

      {/* Wallet Connection */}
      <div className="card">
        <div className="flex items-center gap-3 mb-6">
          <Wallet className="w-6 h-6 text-blue-600" />
          <h3 className="text-lg font-semibold text-gray-900">Wallet Connection</h3>
        </div>
        
        {isConnected ? (
          <div className="space-y-4">
            <div className="flex items-center gap-2">
              <CheckCircle className="w-5 h-5 text-green-600" />
              <span className="text-green-700 font-medium">Wallet Connected</span>
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
              <div>
                <span className="text-gray-600">Address:</span>
                <div className="flex items-center gap-2 mt-1">
                  <span className="font-mono text-sm">{walletAddress}</span>
                  <button
                    onClick={() => copyToClipboard(walletAddress, 'Address')}
                    className="text-blue-600 hover:text-blue-700"
                  >
                    <Copy className="w-4 h-4" />
                  </button>
                </div>
              </div>
              
              <div>
                <span className="text-gray-600">Network:</span>
                <div className="flex items-center gap-2 mt-1">
                  <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                    isCorrectNetwork 
                      ? 'bg-green-100 text-green-800' 
                      : 'bg-red-100 text-red-800'
                  }`}>
                    {isCorrectNetwork ? 'Base Mainnet' : `Chain ID: ${networkId}`}
                  </span>
                  {!isCorrectNetwork && (
                    <button
                      onClick={switchToBase}
                      className="text-blue-600 hover:text-blue-700 text-sm"
                    >
                      Switch to Base
                    </button>
                  )}
                </div>
              </div>
            </div>
            
            {!isCorrectNetwork && (
              <div className="flex items-start gap-2 p-3 bg-yellow-50 rounded-lg">
                <AlertCircle className="w-4 h-4 text-yellow-600 mt-0.5" />
                <div className="text-sm">
                  <p className="font-medium text-yellow-800">Wrong Network</p>
                  <p className="text-yellow-700">Please switch to Base Mainnet to use the application.</p>
                </div>
              </div>
            )}
          </div>
        ) : (
          <div>
            <p className="text-gray-600 mb-4">Connect your wallet to start using the KOL Referral System.</p>
            <button
              onClick={connectWallet}
              className="btn-primary flex items-center gap-2"
            >
              <Wallet className="w-4 h-4" />
              Connect Wallet
            </button>
          </div>
        )}
      </div>

      {/* Contract Addresses */}
      <div className="card">
        <div className="flex items-center gap-3 mb-6">
          <SettingsIcon className="w-6 h-6 text-gray-600" />
          <h3 className="text-lg font-semibold text-gray-900">Contract Addresses</h3>
        </div>
        
        <div className="space-y-4">
          {Object.entries(CONTRACTS).map(([name, address]) => (
            <div key={name} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
              <div>
                <span className="font-medium text-gray-900">{name.toUpperCase()}</span>
                <div className="font-mono text-sm text-gray-600">{address}</div>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => copyToClipboard(address, name)}
                  className="text-blue-600 hover:text-blue-700"
                  title="Copy address"
                >
                  <Copy className="w-4 h-4" />
                </button>
                <a
                  href={`${NETWORK.blockExplorer}/address/${address}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-blue-600 hover:text-blue-700"
                  title="View on explorer"
                >
                  <ExternalLink className="w-4 h-4" />
                </a>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* System Health */}
      <div className="card">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-lg font-semibold text-gray-900">System Health</h3>
          <button
            onClick={fetchSystemHealth}
            className="text-blue-600 hover:text-blue-700 text-sm"
          >
            Refresh
          </button>
        </div>
        
        {systemHealth ? (
          <div className="space-y-4">
            <div className="flex items-center gap-2">
              {systemHealth.status === 'healthy' ? (
                <CheckCircle className="w-5 h-5 text-green-600" />
              ) : (
                <AlertCircle className="w-5 h-5 text-yellow-600" />
              )}
              <span className={`font-medium ${
                systemHealth.status === 'healthy' ? 'text-green-700' : 'text-yellow-700'
              }`}>
                System {systemHealth.status}
              </span>
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {Object.entries(systemHealth.services).map(([service, status]) => (
                <div key={service} className="flex items-center justify-between p-2 bg-gray-50 rounded">
                  <span className="text-sm font-medium text-gray-700">
                    {service.charAt(0).toUpperCase() + service.slice(1)}
                  </span>
                  <span className={`text-xs px-2 py-1 rounded-full font-medium ${
                    status === 'healthy' || status === 'available'
                      ? 'bg-green-100 text-green-800'
                      : 'bg-red-100 text-red-800'
                  }`}>
                    {status}
                  </span>
                </div>
              ))}
            </div>
            
            <div className="text-xs text-gray-500">
              Last updated: {new Date(systemHealth.timestamp).toLocaleString()}
            </div>
          </div>
        ) : (
          <div className="text-center py-4 text-gray-500">
            Loading system health...
          </div>
        )}
      </div>

      {/* Network Info */}
      <div className="card">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Network Information</h3>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <span className="text-gray-600">Network:</span>
            <span className="font-semibold ml-2">{NETWORK.name}</span>
          </div>
          
          <div>
            <span className="text-gray-600">Chain ID:</span>
            <span className="font-semibold ml-2">{NETWORK.chainId}</span>
          </div>
          
          <div>
            <span className="text-gray-600">RPC URL:</span>
            <span className="font-mono text-sm ml-2">{NETWORK.rpcUrl}</span>
          </div>
          
          <div>
            <span className="text-gray-600">Explorer:</span>
            <a
              href={NETWORK.blockExplorer}
              target="_blank"
              rel="noopener noreferrer"
              className="text-blue-600 hover:text-blue-700 ml-2 flex items-center gap-1"
            >
              BaseScan
              <ExternalLink className="w-3 h-3" />
            </a>
          </div>
        </div>
      </div>
    </div>
  );
} 