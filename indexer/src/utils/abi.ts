// EventEmitter ABI - only the events and functions we need
export const EVENT_EMITTER_ABI = [
  "event PoolCreatedDetailed(bytes32 indexed poolId, address indexed creator, address token0, address token1, uint24 tickSpacing, uint8 poolType, uint256 baseFee, uint256 maxImpactFee, uint256 timestamp)",
  "event PoolInitializedDetailed(bytes32 indexed poolId, uint160 sqrtPriceX96, int24 tick, uint256 timestamp)",
  "event SwapExecuted(bytes32 indexed poolId, address indexed sender, address indexed recipient, bool zeroForOne, int256 amount0, int256 amount1, uint160 sqrtPriceX96Before, uint160 sqrtPriceX96After, int24 tickBefore, int24 tickAfter, uint128 liquidity, uint256 feeAmount, uint256 timestamp)",
  "event LiquidityAddedDetailed(bytes32 indexed poolId, address indexed provider, uint256 indexed positionId, int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 amount0, uint256 amount1, uint256 reserve0After, uint256 reserve1After, uint128 totalLiquidityAfter, uint256 timestamp)",
  "event LiquidityRemovedDetailed(bytes32 indexed poolId, address indexed provider, uint256 indexed positionId, uint128 liquidityRemoved, uint256 amount0, uint256 amount1, uint256 reserve0After, uint256 reserve1After, uint128 totalLiquidityAfter, uint256 timestamp)",
  "event FeesCollectedDetailed(bytes32 indexed poolId, address indexed collector, uint256 amount0, uint256 amount1, uint256 protocolFees0Remaining, uint256 protocolFees1Remaining, uint256 timestamp)",
  "event PoolSnapshot(bytes32 indexed poolId, uint160 sqrtPriceX96, int24 currentTick, uint128 liquidity, uint256 reserve0, uint256 reserve1, uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128, uint256 timestamp)",
  "function getPoolCount() view returns (uint256)",
  "function getAllPoolIds() view returns (bytes32[])",
  "function getPoolInfo(bytes32 poolId) view returns (tuple(address token0, address token1, address creator, uint24 tickSpacing, uint256 createdAt, uint256 totalSwaps, uint256 totalVolume0, uint256 totalVolume1, uint160 lastSqrtPriceX96, uint160 previousSqrtPriceX96, int24 lastTick))",
  "function getPoolStats(bytes32 poolId) view returns (uint256 totalSwaps, uint256 totalVolume0, uint256 totalVolume1, uint256 lpCount, uint256 createdAt, address creator)",
  "function getMultiPoolStats(bytes32[] poolIds) view returns (uint256[] swapCounts, uint256[] volumes0, uint256[] volumes1, uint160[] prices)",
  "function getPoolLPs(bytes32 poolId) view returns (address[])",
  "function getPoolLPCount(bytes32 poolId) view returns (uint256)",
  "function isPoolLP(bytes32 poolId, address addr) view returns (bool)",
  "function getReserves(bytes32 poolId) view returns (uint256 reserve0, uint256 reserve1)",
  "function getPrice(bytes32 poolId) view returns (uint160 sqrtPriceX96, int24 tick)",
  "function getPriceChange(bytes32 poolId) view returns (uint160 currentPrice, uint160 previousPrice, int256 priceChangeBps)"
];
