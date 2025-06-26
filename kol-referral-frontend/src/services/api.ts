import axios from 'axios';
import { API_CONFIG } from '@/config/contracts';
import type { 
  FaucetResponse, 
  HealthResponse, 
  ApiOverview,
  KolRegisterRequest,
  KolRegisterResponse,
  UserReferralRequest,
  UserReferralResponse,
  ReferralCodeInfo,
  UserReferralInfo,
  LeaderboardResponse,
  EpochInfo,
  PoolCreateRequest,
  PoolCreateResponse,
  PoolInfo,
  GasEstimate,
  LiquidityAddRequest,
  LiquidityAddResponse,
  LiquidityRemoveRequest,
  UserPositions,
  ServiceHealth
} from '@/types';

const api = axios.create({
  baseURL: API_CONFIG.baseUrl,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// API service functions
export const apiService = {
  // System endpoints
  async getApiOverview(): Promise<ApiOverview> {
    const response = await api.get<ApiOverview>('/');
    return response.data;
  },

  async getHealth(): Promise<HealthResponse> {
    const response = await api.get<HealthResponse>(API_CONFIG.endpoints.health);
    return response.data;
  },

  // Faucet endpoints
  async requestTokens(userAddress: string): Promise<FaucetResponse> {
    const response = await api.post<FaucetResponse>(API_CONFIG.endpoints.faucet, {
      userAddress,
    });
    return response.data;
  },

  async getFaucetHealth(): Promise<ServiceHealth> {
    const response = await api.get<ServiceHealth>(API_CONFIG.endpoints.faucetHealth);
    return response.data;
  },

  // Referral endpoints
  async registerKol(data: KolRegisterRequest): Promise<KolRegisterResponse> {
    const response = await api.post<KolRegisterResponse>(API_CONFIG.endpoints.kolRegister, data);
    return response.data;
  },

  async registerUserReferral(data: UserReferralRequest): Promise<UserReferralResponse> {
    const response = await api.post<UserReferralResponse>(API_CONFIG.endpoints.userRegister, data);
    return response.data;
  },

  async getReferralCodeInfo(code: string): Promise<ReferralCodeInfo> {
    const response = await api.get<ReferralCodeInfo>(`${API_CONFIG.endpoints.referralCode}/${code}`);
    return response.data;
  },

  async getUserReferralInfo(address: string): Promise<UserReferralInfo> {
    const response = await api.get<UserReferralInfo>(`${API_CONFIG.endpoints.userReferral}/${address}`);
    return response.data;
  },

  async getReferralHealth(): Promise<ServiceHealth> {
    const response = await api.get<ServiceHealth>(API_CONFIG.endpoints.referralHealth);
    return response.data;
  },

  // Leaderboard endpoints
  async getLeaderboard(): Promise<LeaderboardResponse> {
    const response = await api.get<LeaderboardResponse>(API_CONFIG.endpoints.leaderboard);
    return response.data;
  },

  async getCurrentEpoch(): Promise<EpochInfo> {
    const response = await api.get<EpochInfo>(API_CONFIG.endpoints.currentEpoch);
    return response.data;
  },

  async getEpochLeaderboard(epochNumber: number): Promise<LeaderboardResponse> {
    const response = await api.get<LeaderboardResponse>(`${API_CONFIG.endpoints.epochLeaderboard}/${epochNumber}`);
    return response.data;
  },

  async getKolRanking(address: string): Promise<any> {
    const response = await api.get(`${API_CONFIG.endpoints.kolRanking}/${address}/ranking`);
    return response.data;
  },

  async getLeaderboardHealth(): Promise<ServiceHealth> {
    const response = await api.get<ServiceHealth>(API_CONFIG.endpoints.leaderboardHealth);
    return response.data;
  },

  // Pool endpoints
  async createPool(data: PoolCreateRequest): Promise<PoolCreateResponse> {
    const response = await api.post<PoolCreateResponse>(API_CONFIG.endpoints.poolCreate, data);
    return response.data;
  },

  async getPoolInfo(poolId: string): Promise<PoolInfo> {
    const response = await api.get<PoolInfo>(`${API_CONFIG.endpoints.poolInfo}/${poolId}/info`);
    return response.data;
  },

  async getTokenBalances(userAddress: string): Promise<any> {
    const response = await api.get(`/api/pool/balances/${userAddress}`);
    return response.data;
  },

  async addLiquidity(data: LiquidityAddRequest): Promise<LiquidityAddResponse> {
    const response = await api.post<LiquidityAddResponse>('/api/pool/add-liquidity', data);
    return response.data;
  },

  async estimatePoolGas(data: Omit<PoolCreateRequest, 'userAddress'>): Promise<GasEstimate> {
    const response = await api.post<GasEstimate>(API_CONFIG.endpoints.poolEstimateGas, data);
    return response.data;
  },

  async simulatePool(data: Omit<PoolCreateRequest, 'userAddress'>): Promise<any> {
    const response = await api.post(API_CONFIG.endpoints.poolSimulate, data);
    return response.data;
  },

  async getPoolHealth(): Promise<ServiceHealth> {
    const response = await api.get<ServiceHealth>(API_CONFIG.endpoints.poolHealth);
    return response.data;
  },

  // Liquidity endpoints
  async removeLiquidity(data: LiquidityRemoveRequest): Promise<any> {
    const response = await api.post(API_CONFIG.endpoints.liquidityRemove, data);
    return response.data;
  },

  async getUserPositions(userAddress: string): Promise<UserPositions> {
    const response = await api.get<UserPositions>(`${API_CONFIG.endpoints.userPositions}/${userAddress}`);
    return response.data;
  },

  async estimateLiquidityGas(data: any): Promise<GasEstimate> {
    const response = await api.post<GasEstimate>(API_CONFIG.endpoints.liquidityEstimateGas, data);
    return response.data;
  },

  async simulateLiquidity(data: any): Promise<any> {
    const response = await api.post(API_CONFIG.endpoints.liquiditySimulate, data);
    return response.data;
  },

  async getLiquidityHealth(): Promise<ServiceHealth> {
    const response = await api.get<ServiceHealth>(API_CONFIG.endpoints.liquidityHealth);
    return response.data;
  },
};

export default apiService; 