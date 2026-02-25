// v5-ASAMM SDK — main entry point

// Client
export { ASAMMClient } from './client';
export type { ASAMMClientConfig } from './client';

// Addresses
export { PAXEER_ADDRESSES, CHAIN_CONFIG, getAddresses } from './addresses';
export type { ChainAddresses, SupportedChainId } from './addresses';

// ABIs
export {
  DiamondABI,
  PoolFacetABI,
  SwapFacetABI,
  LiquidityFacetABI,
  FeeFacetABI,
  OracleFacetABI,
  OraclePegFacetABI,
  OrderFacetABI,
  RewardFacetABI,
  FlashLoanFacetABI,
  EventEmitterABI,
  RouterABI,
  QuoterABI,
} from './abis';

// Types
export {
  PoolType,
  OrderType,
  OrderStatus,
} from './types';

export type {
  PoolConfig,
  PoolState,
  SwapParams,
  SwapResult,
  AddLiquidityParams,
  RemoveLiquidityParams,
  Position,
  FeeConfig,
  PlaceOrderParams,
  Order,
  PegConfig,
  LPRewardInfo,
  TraderRewardInfo,
  EpochConfig,
  EventEmitterPoolInfo,
} from './types';
