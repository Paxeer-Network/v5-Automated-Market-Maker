// TypeScript types matching Solidity structs — for use by frontend consumers

export enum PoolType {
  Standard = 0,
  OraclePegged = 1,
}

export enum OrderType {
  Limit = 0,
  Stop = 1,
}

export enum OrderStatus {
  Active = 0,
  PartiallyFilled = 1,
  Filled = 2,
  Cancelled = 3,
  Expired = 4,
}

export interface PoolConfig {
  token0: string;
  token1: string;
  poolType: PoolType;
  tickSpacing: number;
  sigmoidAlpha: bigint;
  sigmoidK: bigint;
  baseFee: bigint;
  maxImpactFee: bigint;
}

export interface PoolState {
  sqrtPriceX96: bigint;
  currentTick: number;
  liquidity: bigint;
  reserve0: bigint;
  reserve1: bigint;
  feeGrowthGlobal0X128: bigint;
  feeGrowthGlobal1X128: bigint;
  protocolFees0: bigint;
  protocolFees1: bigint;
  lastObservationTimestamp: number;
  initialized: boolean;
}

export interface SwapParams {
  poolId: string;
  zeroForOne: boolean;
  amountSpecified: bigint;
  sqrtPriceLimitX96: bigint;
  recipient: string;
  deadline: number;
}

export interface SwapResult {
  amount0: bigint;
  amount1: bigint;
  sqrtPriceX96After: bigint;
  tickAfter: number;
  liquidityAfter: bigint;
  feeAmount: bigint;
}

export interface AddLiquidityParams {
  poolId: string;
  tickLower: number;
  tickUpper: number;
  amount0Desired: bigint;
  amount1Desired: bigint;
  amount0Min: bigint;
  amount1Min: bigint;
  recipient: string;
  deadline: number;
}

export interface RemoveLiquidityParams {
  poolId: string;
  positionId: number;
  liquidityAmount: bigint;
  amount0Min: bigint;
  amount1Min: bigint;
  recipient: string;
  deadline: number;
}

export interface Position {
  poolId: string;
  owner: string;
  tickLower: number;
  tickUpper: number;
  liquidity: bigint;
  feeGrowthInside0LastX128: bigint;
  feeGrowthInside1LastX128: bigint;
  tokensOwed0: bigint;
  tokensOwed1: bigint;
  depositTimestamp: bigint;
  cumulativeVolume: bigint;
}

export interface FeeConfig {
  baseFee: bigint;
  maxImpactFee: bigint;
  lpShareBps: bigint;
  protocolShareBps: bigint;
  traderShareBps: bigint;
}

export interface PlaceOrderParams {
  poolId: string;
  orderType: OrderType;
  zeroForOne: boolean;
  targetTick: number;
  amount: bigint;
  expiry: number;
}

export interface Order {
  orderId: bigint;
  poolId: string;
  owner: string;
  orderType: OrderType;
  zeroForOne: boolean;
  targetTick: number;
  amountTotal: bigint;
  amountFilled: bigint;
  depositTimestamp: bigint;
  expiry: bigint;
  status: OrderStatus;
}

export interface PegConfig {
  oracleAddress: string;
  twapPeriod: number;
  maxStaleness: number;
  maxSpotDeviation: bigint;
}

export interface LPRewardInfo {
  loyaltyMultiplier: bigint;
  accumulatedFees0: bigint;
  accumulatedFees1: bigint;
  depositTimestamp: bigint;
  cumulativeVolume: bigint;
}

export interface TraderRewardInfo {
  currentEpoch: bigint;
  epochSwapCount: bigint;
  epochVolume: bigint;
  pendingRebate0: bigint;
  pendingRebate1: bigint;
}

export interface EpochConfig {
  epochDuration: bigint;
  minSwapsForRebate: bigint;
  maxTradeSize: bigint;
}

export interface EventEmitterPoolInfo {
  token0: string;
  token1: string;
  creator: string;
  tickSpacing: number;
  createdAt: bigint;
  totalSwaps: bigint;
  totalVolume0: bigint;
  totalVolume1: bigint;
  lastSqrtPriceX96: bigint;
  previousSqrtPriceX96: bigint;
  lastTick: number;
}
