export const typeDefs = `#graphql
  type Pool {
    poolId: String!
    creator: String!
    token0: String!
    token1: String!
    tickSpacing: Int!
    poolType: Int!
    baseFee: String!
    maxImpactFee: String!
    sqrtPriceX96: String!
    currentTick: Int!
    liquidity: String!
    reserve0: String!
    reserve1: String!
    totalSwaps: Int!
    totalVolume0: String!
    totalVolume1: String!
    totalFees0: String!
    totalFees1: String!
    lpCount: Int!
    initialized: Boolean!
    createdAt: Int!
    createdBlock: Int!
    createdTx: String!
  }

  type Swap {
    id: Int!
    poolId: String!
    sender: String!
    recipient: String!
    zeroForOne: Boolean!
    amount0: String!
    amount1: String!
    sqrtPriceBefore: String!
    sqrtPriceAfter: String!
    tickBefore: Int!
    tickAfter: Int!
    liquidity: String!
    feeAmount: String!
    timestamp: Int!
    blockNumber: Int!
    txHash: String!
  }

  type LiquidityEvent {
    id: Int!
    poolId: String!
    provider: String!
    positionId: Int!
    eventType: String!
    tickLower: Int
    tickUpper: Int
    liquidity: String!
    amount0: String!
    amount1: String!
    reserve0After: String!
    reserve1After: String!
    totalLiquidityAfter: String!
    timestamp: Int!
    blockNumber: Int!
    txHash: String!
  }

  type FeeCollection {
    id: Int!
    poolId: String!
    collector: String!
    amount0: String!
    amount1: String!
    protocolFees0Remaining: String!
    protocolFees1Remaining: String!
    timestamp: Int!
    blockNumber: Int!
    txHash: String!
  }

  type PoolSnapshot {
    id: Int!
    poolId: String!
    sqrtPriceX96: String!
    currentTick: Int!
    liquidity: String!
    reserve0: String!
    reserve1: String!
    feeGrowthGlobal0: String!
    feeGrowthGlobal1: String!
    timestamp: Int!
    blockNumber: Int!
  }

  type PoolStats {
    poolId: String!
    totalSwaps: Int!
    totalVolume0: String!
    totalVolume1: String!
    totalFees0: String!
    totalFees1: String!
    lpCount: Int!
    uniqueTraders: Int!
    swaps24h: Int!
    volume0_24h: String!
    volume1_24h: String!
  }

  type IndexerStatus {
    lastIndexedBlock: Int!
    latestBlock: Int!
    behind: Int!
    poolCount: Int!
    totalSwaps: Int!
  }

  type TopTrader {
    address: String!
    swapCount: Int!
    totalVolume0: String!
    totalVolume1: String!
  }

  type TopLP {
    address: String!
    eventCount: Int!
    totalAmount0: String!
    totalAmount1: String!
  }

  type PriceCandle {
    timestamp: Int!
    open: String!
    high: String!
    low: String!
    close: String!
    volume0: String!
    volume1: String!
    swapCount: Int!
  }

  type PaginatedSwaps {
    items: [Swap!]!
    total: Int!
    hasMore: Boolean!
  }

  type PaginatedLiquidityEvents {
    items: [LiquidityEvent!]!
    total: Int!
    hasMore: Boolean!
  }

  type Query {
    # Pools
    pool(poolId: String!): Pool
    pools(limit: Int, offset: Int, orderBy: String): [Pool!]!
    poolCount: Int!

    # Swaps
    swap(id: Int!): Swap
    swaps(poolId: String, sender: String, limit: Int, offset: Int): PaginatedSwaps!
    recentSwaps(poolId: String, limit: Int): [Swap!]!

    # Liquidity
    liquidityEvents(poolId: String, provider: String, eventType: String, limit: Int, offset: Int): PaginatedLiquidityEvents!

    # Fees
    feeCollections(poolId: String, limit: Int, offset: Int): [FeeCollection!]!

    # Snapshots
    poolSnapshots(poolId: String!, limit: Int, fromTimestamp: Int, toTimestamp: Int): [PoolSnapshot!]!

    # Analytics
    poolStats(poolId: String!): PoolStats
    topTraders(poolId: String, limit: Int): [TopTrader!]!
    topLPs(poolId: String, limit: Int): [TopLP!]!
    priceCandles(poolId: String!, interval: Int!, from: Int!, to: Int!): [PriceCandle!]!

    # System
    indexerStatus: IndexerStatus!
  }
`;
