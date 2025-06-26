import { useState, useEffect, useCallback } from 'react';
import { ethers } from 'ethers';
import { NETWORK } from '@/config/contracts';
import type { WalletState } from '@/types';
import toast from 'react-hot-toast';

export function useWeb3() {
  const [walletState, setWalletState] = useState<WalletState>({
    address: null,
    isConnected: false,
    balance: '0',
    network: null,
  });

  const [isConnecting, setIsConnecting] = useState(false);

  const isMetaMaskAvailable = useCallback(() => {
    return typeof window !== 'undefined' && window.ethereum;
  }, []);

  const getProvider = useCallback(() => {
    if (!isMetaMaskAvailable() || !window.ethereum) {
      throw new Error('MetaMask not available');
    }
    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      return provider;
    } catch (error) {
      console.error('Error creating provider:', error);
      throw error;
    }
  }, [isMetaMaskAvailable]);

  const updateBalance = useCallback(async (address: string) => {
    try {
      const provider = getProvider();
      const balance = await provider.getBalance(address);
      const balanceInEth = ethers.formatEther(balance);
      setWalletState(prev => ({ ...prev, balance: balanceInEth }));
    } catch (error) {
      console.error('Error getting balance:', error);
    }
  }, [getProvider]);

  const connectWallet = useCallback(async () => {
    if (!isMetaMaskAvailable()) {
      toast.error('MetaMask not detected. Please install MetaMask.');
      return false;
    }

    setIsConnecting(true);
    try {
      if (!window.ethereum) return false;
      
      const accounts = await window.ethereum.request({ 
        method: 'eth_requestAccounts' 
      });
      
      if (accounts.length > 0) {
        const provider = getProvider();
        const network = await provider.getNetwork();
        
        setWalletState({
          address: accounts[0],
        isConnected: true,
          balance: '0',
          network: Number(network.chainId),
      });

        await updateBalance(accounts[0]);
        toast.success('Wallet connected successfully!');
        return true;
      }
    } catch (error: any) {
      console.error('Error connecting wallet:', error);
      if (error.code === 4001) {
        toast.error('Please connect to MetaMask');
      } else {
        toast.error('Failed to connect wallet');
      }
    } finally {
      setIsConnecting(false);
    }
    return false;
  }, [isMetaMaskAvailable, getProvider, updateBalance]);

  const disconnectWallet = useCallback(() => {
    setWalletState({
      address: null,
      isConnected: false,
      balance: '0',
      network: null,
    });
    toast.success('Wallet disconnected');
  }, []);

  const switchToBaseNetwork = useCallback(async () => {
    if (!isMetaMaskAvailable() || !window.ethereum) {
      toast.error('MetaMask not available');
      return false;
    }

    try {
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: `0x${NETWORK.chainId.toString(16)}` }],
      });
      return true;
    } catch (error: any) {
      if (error.code === 4902) {
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
          return true;
        } catch (addError) {
          console.error('Error adding Base network:', addError);
          toast.error('Failed to add Base network');
        }
      } else {
        console.error('Error switching to Base:', error);
        toast.error('Failed to switch to Base network');
      }
    }
    return false;
  }, [isMetaMaskAvailable]);

  const checkConnection = useCallback(async () => {
    if (!isMetaMaskAvailable() || !window.ethereum) return;

    try {
      const accounts = await window.ethereum.request({ method: 'eth_accounts' });
      if (accounts.length > 0) {
        const provider = getProvider();
        const network = await provider.getNetwork();
        
        setWalletState({
          address: accounts[0],
          isConnected: true,
          balance: '0',
          network: Number(network.chainId),
        });
        
        await updateBalance(accounts[0]);
      }
    } catch (error) {
      console.error('Error checking connection:', error);
    }
  }, [isMetaMaskAvailable, getProvider, updateBalance]);

  useEffect(() => {
    checkConnection();
  }, [checkConnection]);

  useEffect(() => {
    if (!isMetaMaskAvailable() || !window.ethereum) return;

    const handleAccountsChanged = (accounts: string[]) => {
      if (accounts.length === 0) {
        setWalletState({
          address: null,
          isConnected: false,
          balance: '0',
          network: null,
        });
      } else {
        checkConnection();
      }
    };

    const handleChainChanged = () => {
      checkConnection();
    };

    window.ethereum.on('accountsChanged', handleAccountsChanged);
    window.ethereum.on('chainChanged', handleChainChanged);

    return () => {
      if (window.ethereum) {
      window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
      window.ethereum.removeListener('chainChanged', handleChainChanged);
      }
    };
  }, [isMetaMaskAvailable, checkConnection]);

  return {
    ...walletState,
    isConnecting,
    isMetaMaskAvailable: isMetaMaskAvailable(),
    getProvider,
    connectWallet,
    disconnectWallet,
    switchToBaseNetwork,
    updateBalance: () => walletState.address ? updateBalance(walletState.address) : Promise.resolve(),
  };
} 