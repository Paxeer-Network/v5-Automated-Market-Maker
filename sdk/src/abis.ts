// Human-readable ABIs for all protocol contracts
// Derived directly from the verified Solidity source code

export const PoolFacetABI = [
  "function createPool(tuple(address token0, address token1, uint8 poolType, uint24 tickSpacing, uint256 sigmoidAlpha, uint256 sigmoidK, uint256 baseFee, uint256 maxImpactFee) config) external returns (bytes32 poolId)",
  "function initializePool(bytes32 poolId, uint160 sqrtPriceX96) external",
  "function getPoolState(bytes32 poolId) external view returns (tuple(uint160 sqrtPriceX96, int24 currentTick, uint128 liquidity, uint256 reserve0, uint256 reserve1, uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128, uint256 protocolFees0, uint256 protocolFees1, uint32 lastObservationTimestamp, bool initialized))",
  "function computePoolId(address token0, address token1, uint24 tickSpacing) external pure returns (bytes32)",
  "function poolExists(bytes32 poolId) external view returns (bool)",
  "function getPoolCount() external view returns (uint256)",
  "function getPoolConfig(bytes32 poolId) external view returns (tuple(address token0, address token1, uint8 poolType, uint24 tickSpacing, uint256 sigmoidAlpha, uint256 sigmoidK, uint256 baseFee, uint256 maxImpactFee))",
  "function getAllPoolIds() external view returns (bytes32[])",
  "function getPoolCreator(bytes32 poolId) external view returns (address)",
  "function pause() external",
  "function unpause() external",
  "function setEventEmitter(address emitter) external",
  "event PoolCreated(bytes32 indexed poolId, address indexed token0, address indexed token1, uint8 poolType, uint24 tickSpacing)",
  "event PoolInitialized(bytes32 indexed poolId, uint160 sqrtPriceX96, int24 tick)",
];

export const SwapFacetABI = [
  "function swap(tuple(bytes32 poolId, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, address recipient, uint256 deadline) params) external returns (tuple(int256 amount0, int256 amount1, uint160 sqrtPriceX96After, int24 tickAfter, uint128 liquidityAfter, uint256 feeAmount))",
  "event Swap(bytes32 indexed poolId, address indexed sender, address indexed recipient, int256 amount0, int256 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick, uint256 fee)",
];

export const LiquidityFacetABI = [
  "function addLiquidity(tuple(bytes32 poolId, int24 tickLower, int24 tickUpper, uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address recipient, uint256 deadline) params) external returns (uint256 positionId, uint128 liquidity, uint256 amount0, uint256 amount1)",
  "function removeLiquidity(tuple(bytes32 poolId, uint256 positionId, uint128 liquidityAmount, uint256 amount0Min, uint256 amount1Min, address recipient, uint256 deadline) params) external returns (uint256 amount0, uint256 amount1)",
  "function collectFees(bytes32 poolId, uint256 positionId, address recipient) external returns (uint256 amount0, uint256 amount1)",
  "function getPosition(uint256 positionId) external view returns (tuple(bytes32 poolId, address owner, int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, uint256 tokensOwed0, uint256 tokensOwed1, uint256 depositTimestamp, uint256 cumulativeVolume))",
  "event LiquidityAdded(bytes32 indexed poolId, address indexed owner, uint256 indexed positionId, int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 amount0, uint256 amount1)",
  "event LiquidityRemoved(bytes32 indexed poolId, address indexed owner, uint256 indexed positionId, int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 amount0, uint256 amount1)",
  "event FeesCollected(bytes32 indexed poolId, address indexed owner, uint256 indexed positionId, uint256 amount0, uint256 amount1)",
];

export const FeeFacetABI = [
  "function calculateFee(bytes32 poolId, uint256 tradeSize) external view returns (uint256 feeBps)",
  "function setFeeConfig(bytes32 poolId, tuple(uint256 baseFee, uint256 maxImpactFee, uint256 lpShareBps, uint256 protocolShareBps, uint256 traderShareBps) config) external",
  "function collectProtocolFees(bytes32 poolId, address recipient) external returns (uint256 amount0, uint256 amount1)",
  "function getFeeConfig(bytes32 poolId) external view returns (tuple(uint256 baseFee, uint256 maxImpactFee, uint256 lpShareBps, uint256 protocolShareBps, uint256 traderShareBps))",
  "event FeeConfigUpdated(bytes32 indexed poolId, uint256 baseFee, uint256 maxImpactFee)",
  "event ProtocolFeesCollected(bytes32 indexed poolId, uint256 amount0, uint256 amount1)",
];

export const OracleFacetABI = [
  "function consultTWAP(bytes32 poolId, uint32 period) external view returns (int24 arithmeticMeanTick)",
  "function getSpotTick(bytes32 poolId) external view returns (int24 tick)",
  "function observe(bytes32 poolId, uint32[] secondsAgos) external view returns (int56[] tickCumulatives)",
  "function increaseObservationCardinalityNext(bytes32 poolId, uint16 observationCardinalityNext) external",
];

export const OraclePegFacetABI = [
  "function setOraclePeg(bytes32 poolId, tuple(address oracleAddress, uint32 twapPeriod, uint32 maxStaleness, uint256 maxSpotDeviation) config) external",
  "function removeOraclePeg(bytes32 poolId) external",
  "function getOracleMidPrice(bytes32 poolId) external view returns (uint256 midPrice, bool isValid)",
  "function getPegConfig(bytes32 poolId) external view returns (tuple(address oracleAddress, uint32 twapPeriod, uint32 maxStaleness, uint256 maxSpotDeviation))",
];

export const OrderFacetABI = [
  "function placeOrder(tuple(bytes32 poolId, uint8 orderType, bool zeroForOne, int24 targetTick, uint256 amount, uint256 expiry) params) external returns (uint256 orderId)",
  "function cancelOrder(uint256 orderId) external",
  "function executeOrder(uint256 orderId) external returns (uint256 amountOut, uint256 bounty)",
  "function getOrder(uint256 orderId) external view returns (tuple(uint256 orderId, bytes32 poolId, address owner, uint8 orderType, bool zeroForOne, int24 targetTick, uint256 amountTotal, uint256 amountFilled, uint256 depositTimestamp, uint256 expiry, uint8 status))",
  "function getOrdersAtTick(bytes32 poolId, int24 tick) external view returns (uint256[])",
  "function getActiveOrderCount(bytes32 poolId) external view returns (uint256)",
  "event OrderPlaced(uint256 indexed orderId, bytes32 indexed poolId, address indexed owner, uint8 orderType, int24 targetTick, uint256 amount)",
  "event OrderFilled(uint256 indexed orderId, uint256 amountFilled, uint256 amountOut)",
  "event OrderCancelled(uint256 indexed orderId)",
];

export const RewardFacetABI = [
  "function getLPMultiplier(uint256 positionId) external view returns (uint256 multiplier)",
  "function getLPRewardInfo(uint256 positionId) external view returns (tuple(uint256 loyaltyMultiplier, uint256 accumulatedFees0, uint256 accumulatedFees1, uint256 depositTimestamp, uint256 cumulativeVolume))",
  "function getTraderRewardInfo(address trader) external view returns (tuple(uint256 currentEpoch, uint256 epochSwapCount, uint256 epochVolume, uint256 pendingRebate0, uint256 pendingRebate1))",
  "function claimTraderRebate(address recipient) external returns (uint256 amount0, uint256 amount1)",
  "function advanceEpoch() external",
  "function setEpochConfig(tuple(uint256 epochDuration, uint256 minSwapsForRebate, uint256 maxTradeSize) config) external",
  "function getCurrentEpoch() external view returns (uint256 epoch, uint256 startTime, uint256 endTime)",
];

export const FlashLoanFacetABI = [
  "function flashLoan(address receiver, address token, uint256 amount, bytes data) external",
  "function getFlashLoanFee(uint256 amount) external view returns (uint256 fee)",
  "event FlashLoan(address indexed receiver, address indexed token, uint256 amount, uint256 fee)",
];

export const EventEmitterABI = [
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
  "function getPriceChange(bytes32 poolId) view returns (uint160 currentPrice, uint160 previousPrice, int256 priceChangeBps)",
];

// Combined Diamond ABI (all facets merged) for use with a single contract instance
export const DiamondABI = [
  ...PoolFacetABI,
  ...SwapFacetABI,
  ...LiquidityFacetABI,
  ...FeeFacetABI,
  ...OracleFacetABI,
  ...OraclePegFacetABI,
  ...OrderFacetABI,
  ...RewardFacetABI,
  ...FlashLoanFacetABI,
];

export const RouterABI = [
  "function exactInputSingle(tuple(address tokenIn, address tokenOut, uint24 tickSpacing, address recipient, uint256 deadline, uint256 amountIn, uint256 amountOutMinimum, uint160 sqrtPriceLimitX96) params) external payable returns (uint256 amountOut)",
  "function exactInput(tuple(bytes path, address recipient, uint256 deadline, uint256 amountIn, uint256 amountOutMinimum) params) external payable returns (uint256 amountOut)",
  "function exactOutputSingle(tuple(address tokenIn, address tokenOut, uint24 tickSpacing, address recipient, uint256 deadline, uint256 amountOut, uint256 amountInMaximum, uint160 sqrtPriceLimitX96) params) external payable returns (uint256 amountIn)",
];

export const QuoterABI = [
  "function quoteExactInputSingle(tuple(address tokenIn, address tokenOut, uint24 tickSpacing, uint256 amountIn, uint160 sqrtPriceLimitX96) params) external returns (uint256 amountOut, uint160 sqrtPriceX96After, int24 tickAfter)",
  "function quoteExactInput(bytes path, uint256 amountIn) external returns (uint256 amountOut)",
];
