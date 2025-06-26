import { useState } from 'react';
import { Coins, CheckCircle, AlertCircle, Copy, ExternalLink } from 'lucide-react';
import { useWeb3 } from '@/hooks/useWeb3';
import { apiService } from '@/services/api';
import { formatAddress, copyToClipboard } from '@/lib/utils';
import { CONTRACTS, NETWORK } from '@/config/contracts';
import toast from 'react-hot-toast';

interface FaucetResponse {
  success: boolean;
  message: string;
  txHash1?: string;
  txHash2?: string;
}

export function Faucet() {
  const { address, isConnected } = useWeb3();
  const [isLoading, setIsLoading] = useState(false);
  const [lastResponse, setLastResponse] = useState<FaucetResponse | null>(null);

  const handleRequestTokens = async () => {
    if (!isConnected || !address) {
      toast.error('Please connect your wallet first');
      return;
    }

    setIsLoading(true);
    try {
      const response = await apiService.requestTokens(address);
      setLastResponse(response);
      
      if (response.success) {
        toast.success('Tokens sent successfully!');
      } else {
        toast.error(response.message);
      }
    } catch (error) {
      console.error('Faucet error:', error);
      toast.error('Failed to request tokens. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const copyAddress = async (address: string) => {
    await copyToClipboard(address);
    toast.success('Address copied to clipboard');
  };

  const openTransaction = (txHash: string) => {
    window.open(`${NETWORK.blockExplorer}/tx/${txHash}`, '_blank');
  };

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Faucet</h1>
        <p className="text-gray-600 mt-2">
          Request KOLTEST1 and KOLTEST2 tokens for testing the referral system.
        </p>
      </div>

      {/* Faucet Card */}
      <div className="card max-w-2xl">
        <div className="flex items-center space-x-3 mb-6">
          <div className="p-2 bg-primary-50 rounded-lg">
            <Coins className="w-6 h-6 text-primary-600" />
          </div>
          <div>
            <h2 className="text-xl font-semibold text-gray-900">Request Test Tokens</h2>
            <p className="text-sm text-gray-600">Get tokens to test the KOL referral system</p>
          </div>
        </div>

        {/* Rate Limit Info */}
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
          <div className="flex items-start space-x-3">
            <AlertCircle className="w-5 h-5 text-blue-600 mt-0.5" />
            <div>
              <h3 className="text-sm font-medium text-blue-900">Rate Limiting</h3>
              <p className="text-sm text-blue-700 mt-1">
                You can request tokens once per 24 hours per wallet address.
              </p>
            </div>
          </div>
        </div>

        {/* Wallet Status */}
        {isConnected ? (
          <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
            <div className="flex items-center space-x-3">
              <CheckCircle className="w-5 h-5 text-green-600" />
              <div>
                <p className="text-sm font-medium text-green-900">Wallet Connected</p>
                <p className="text-sm text-green-700">
                  {formatAddress(address || '')}
                </p>
              </div>
            </div>
          </div>
        ) : (
          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
            <div className="flex items-center space-x-3">
              <AlertCircle className="w-5 h-5 text-yellow-600" />
              <div>
                <p className="text-sm font-medium text-yellow-900">Wallet Not Connected</p>
                <p className="text-sm text-yellow-700">
                  Please connect your wallet to request tokens.
                </p>
              </div>
            </div>
          </div>
        )}

        {/* Request Button */}
        <button
          onClick={handleRequestTokens}
          disabled={!isConnected || isLoading}
          className="w-full btn-primary disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isLoading ? 'Requesting Tokens...' : 'Request Tokens'}
        </button>

        {/* Last Response */}
        {lastResponse && (
          <div className="mt-6 p-4 border rounded-lg">
            <h3 className="text-sm font-medium text-gray-900 mb-2">Last Request Result</h3>
            <div className="space-y-2">
              <div className="flex items-center space-x-2">
                <span className="text-sm text-gray-600">Status:</span>
                <span className={`text-sm font-medium ${
                  lastResponse.success ? 'text-green-600' : 'text-red-600'
                }`}>
                  {lastResponse.success ? 'Success' : 'Failed'}
                </span>
              </div>
              <div>
                <span className="text-sm text-gray-600">Message:</span>
                <p className="text-sm text-gray-900">{lastResponse.message}</p>
              </div>
              {lastResponse.txHash1 && (
                <div className="flex items-center space-x-2">
                  <span className="text-sm text-gray-600">KOLTEST1 TX:</span>
                  <button
                    onClick={() => openTransaction(lastResponse.txHash1!)}
                    className="text-sm text-primary-600 hover:text-primary-700 flex items-center space-x-1"
                  >
                    <span>{formatAddress(lastResponse.txHash1)}</span>
                    <ExternalLink className="w-3 h-3" />
                  </button>
                </div>
              )}
              {lastResponse.txHash2 && (
                <div className="flex items-center space-x-2">
                  <span className="text-sm text-gray-600">KOLTEST2 TX:</span>
                  <button
                    onClick={() => openTransaction(lastResponse.txHash2!)}
                    className="text-sm text-primary-600 hover:text-primary-700 flex items-center space-x-1"
                  >
                    <span>{formatAddress(lastResponse.txHash2)}</span>
                    <ExternalLink className="w-3 h-3" />
                  </button>
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Token Information */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="card">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">KOLTEST1 Token</h3>
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Address:</span>
              <div className="flex items-center space-x-2">
                <span className="font-mono text-sm">{formatAddress(CONTRACTS.KOLTEST1)}</span>
                <button
                  onClick={() => copyAddress(CONTRACTS.KOLTEST1)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <Copy className="w-4 h-4" />
                </button>
              </div>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Decimals:</span>
              <span className="text-sm">18</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Network:</span>
              <span className="text-sm">{NETWORK.name}</span>
            </div>
          </div>
        </div>

        <div className="card">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">KOLTEST2 Token</h3>
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Address:</span>
              <div className="flex items-center space-x-2">
                <span className="font-mono text-sm">{formatAddress(CONTRACTS.KOLTEST2)}</span>
                <button
                  onClick={() => copyAddress(CONTRACTS.KOLTEST2)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <Copy className="w-4 h-4" />
                </button>
              </div>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Decimals:</span>
              <span className="text-sm">18</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Network:</span>
              <span className="text-sm">{NETWORK.name}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
} 