// Web3 types
export interface WalletInfo {
  address: string;
  isConnected: boolean;
  chainId?: number;
}

// Common types
export interface Address {
  value: string;
}

export interface TxHash {
  value: string;
}

export interface ApiResponse<T = any> {
  success: boolean;
  message: string;
  data?: T;
}

// System types
export interface HealthResponse {
  status: 'healthy' | 'degraded';
  timestamp: string;
  services: {
    blockchain: string;
    faucet: string;
    referralRegistry: string;
    leaderboard: string;
    poolManager: string;
    liquidityManager: string;
  };
  framework: string;
  environment: string;
  contracts: {
    koltest1: string;
    koltest2: string;
    referralRegistry: string;
  };
}

export interface ApiOverview {
  name: string;
  version: string;
  description: string;
  endpoints: Record<string, string>;
  status: string;
  framework: string;
  blockchain: string;
  services: {
    blockchain: string;
  };
}

// Faucet types
export interface FaucetRequest {
  userAddress: string;
}

export interface FaucetResponse extends ApiResponse {
  data: {
    userAddress: string;
    txHash1: string;
    txHash2: string;
    amounts: {
      koltest1: string;
      koltest2: string;
    };
  };
}

// Referral types
export interface KolRegisterRequest {
  kolAddress: string;
  referralCode: string;
  socialHandle: string;
}

export interface KolRegisterResponse extends ApiResponse {
  data: {
    kolAddress: string;
    referralCode: string;
    nftTokenId: string;
    transactionHash: string;
  };
}

export interface UserReferralRequest {
  userAddress: string;
  referralCode: string;
}

export interface UserReferralResponse extends ApiResponse {
  data: {
    userAddress: string;
    referralCode: string;
    kolAddress: string;
    transactionHash: string;
  };
}

export interface ReferralCodeInfo extends ApiResponse {
  data: {
    referralCode: string;
    kolAddress: string;
    isActive: boolean;
    totalReferrals: string;
    totalTVL: string;
    uniqueUsers: string;
    referredUsers: string[];
    socialHandle?: string;
    tokenId?: string;
  };
}

export interface UserReferralInfo extends ApiResponse {
  data: {
    userAddress: string;
    referralCode: string;
    kolAddress: string;
    registrationDate: string;
  };
}

// Leaderboard types
export interface KolRanking {
  rank: number;
  kolAddress: string;
  referralCode: string;
  totalTvl: string;
  referralCount: number;
  points: string;
}

export interface LeaderboardResponse extends ApiResponse {
  data: {
  epoch: number;
    rankings: KolRanking[];
  };
}

export interface EpochInfo extends ApiResponse {
  data: {
    currentEpoch: number;
    startTime: string;
    endTime: string;
    isActive: boolean;
  };
}

// Pool types
export interface PoolCreateRequest {
  token0: string;
  token1: string;
  fee: number;
  tickSpacing: number;
  hookAddress: string;
  initialPriceX96?: string;
  userAddress: string;
}

export interface PoolCreateResponse extends ApiResponse {
  data: {
    poolId: string;
    currency0: string;
    currency1: string;
    fee: number;
    tickSpacing: number;
    hookAddress: string;
    transactionHash: string;
    blockNumber: number;
  };
}

export interface PoolInfo extends ApiResponse {
  data: {
    poolId: string;
    sqrtPriceX96: string;
    tick: string;
    protocolFee: number;
    lpFee: number;
    liquidity: string;
    isInitialized: boolean;
  };
}

export interface GasEstimate extends ApiResponse {
  data: {
    gasLimit: string;
    gasPrice: string;
    estimatedCost: string;
    operation?: string;
  };
}

// Liquidity types
export interface LiquidityAddRequest {
  poolId: string;
  token0: string;
  token1: string;
  fee: number;
  tickSpacing: number;
  hookAddress: string;
  tickLower: number;
  tickUpper: number;
  amount0Desired: string;
  amount1Desired: string;
  amount0Min?: string;
  amount1Min?: string;
  userAddress: string;
  referralCode?: string;
}

export interface LiquidityAddResponse extends ApiResponse {
  data: {
    tokenId: string;
    poolId: string;
    amount0: string;
    amount1: string;
    userAddress: string;
    referralCode?: string;
    transactionHash: string;
  };
}

export interface LiquidityRemoveRequest {
  poolId: string;
  token0: string;
  token1: string;
  fee: number;
  tickSpacing: number;
  hookAddress: string;
  tickLower: number;
  tickUpper: number;
  liquidity: string;
  amount0Min?: string;
  amount1Min?: string;
  userAddress: string;
}

export interface LiquidityPosition {
  tokenId: string;
  poolId: string;
  tickLower: number;
  tickUpper: number;
  liquidity: string;
  token0: string;
  token1: string;
  amount0?: string;
  amount1?: string;
  fees0?: string;
  fees1?: string;
}

export interface UserPositions extends ApiResponse {
  data: {
    userAddress: string;
    positions: LiquidityPosition[];
    totalPositions: number;
  };
}

// Wallet types
export interface WalletState {
  address: string | null;
  isConnected: boolean;
  balance: string;
  network: number | null;
}

// UI types
export interface NavItem {
  label: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
}

export interface StatCard {
  title: string;
  value: string;
  change?: string;
  changeType?: 'positive' | 'negative' | 'neutral';
  icon: React.ComponentType<{ className?: string }>;
}

export interface TabItem {
  id: string;
  label: string;
  icon: any;
}

export interface ServiceHealth {
  status: string;
  endpoints: string[];
} 