import { query } from '../utils/db';
import { cacheGet, cacheSet } from '../utils/redis';

// Helper: map DB row to GraphQL Pool
function mapPool(row: any) {
  return {
    poolId: row.pool_id,
    creator: row.creator,
    token0: row.token0,
    token1: row.token1,
    tickSpacing: row.tick_spacing,
    poolType: row.pool_type,
    baseFee: row.base_fee,
    maxImpactFee: row.max_impact_fee,
    sqrtPriceX96: row.sqrt_price_x96,
    currentTick: row.current_tick,
    liquidity: row.liquidity,
    reserve0: row.reserve0,
    reserve1: row.reserve1,
    totalSwaps: row.total_swaps,
    totalVolume0: row.total_volume0,
    totalVolume1: row.total_volume1,
    totalFees0: row.total_fees0,
    totalFees1: row.total_fees1,
    lpCount: row.lp_count,
    initialized: row.initialized,
    createdAt: row.created_at,
    createdBlock: row.created_block,
    createdTx: row.created_tx,
  };
}

function mapSwap(row: any) {
  return {
    id: row.id,
    poolId: row.pool_id,
    sender: row.sender,
    recipient: row.recipient,
    zeroForOne: row.zero_for_one,
    amount0: row.amount0,
    amount1: row.amount1,
    sqrtPriceBefore: row.sqrt_price_before,
    sqrtPriceAfter: row.sqrt_price_after,
    tickBefore: row.tick_before,
    tickAfter: row.tick_after,
    liquidity: row.liquidity,
    feeAmount: row.fee_amount,
    timestamp: row.timestamp,
    blockNumber: row.block_number,
    txHash: row.tx_hash,
  };
}

function mapLiqEvent(row: any) {
  return {
    id: row.id,
    poolId: row.pool_id,
    provider: row.provider,
    positionId: row.position_id,
    eventType: row.event_type,
    tickLower: row.tick_lower,
    tickUpper: row.tick_upper,
    liquidity: row.liquidity,
    amount0: row.amount0,
    amount1: row.amount1,
    reserve0After: row.reserve0_after,
    reserve1After: row.reserve1_after,
    totalLiquidityAfter: row.total_liquidity_after,
    timestamp: row.timestamp,
    blockNumber: row.block_number,
    txHash: row.tx_hash,
  };
}

function mapFeeCollection(row: any) {
  return {
    id: row.id,
    poolId: row.pool_id,
    collector: row.collector,
    amount0: row.amount0,
    amount1: row.amount1,
    protocolFees0Remaining: row.protocol_fees0_remaining,
    protocolFees1Remaining: row.protocol_fees1_remaining,
    timestamp: row.timestamp,
    blockNumber: row.block_number,
    txHash: row.tx_hash,
  };
}

function mapSnapshot(row: any) {
  return {
    id: row.id,
    poolId: row.pool_id,
    sqrtPriceX96: row.sqrt_price_x96,
    currentTick: row.current_tick,
    liquidity: row.liquidity,
    reserve0: row.reserve0,
    reserve1: row.reserve1,
    feeGrowthGlobal0: row.fee_growth_global0,
    feeGrowthGlobal1: row.fee_growth_global1,
    timestamp: row.timestamp,
    blockNumber: row.block_number,
  };
}

export const resolvers = {
  Query: {
    // ── Pools ──
    pool: async (_: any, { poolId }: { poolId: string }) => {
      const cached = await cacheGet<any>(`pool:${poolId}`);
      if (cached) return cached;

      const res = await query('SELECT * FROM pools WHERE pool_id = $1', [poolId]);
      if (res.rows.length === 0) return null;
      const pool = mapPool(res.rows[0]);
      await cacheSet(`pool:${poolId}`, pool, 5);
      return pool;
    },

    pools: async (_: any, { limit = 50, offset = 0, orderBy = 'created_at' }: any) => {
      const validOrderBy = ['created_at', 'total_swaps', 'total_volume0', 'liquidity'].includes(orderBy) ? orderBy : 'created_at';
      const res = await query(`SELECT * FROM pools ORDER BY ${validOrderBy} DESC LIMIT $1 OFFSET $2`, [limit, offset]);
      return res.rows.map(mapPool);
    },

    poolCount: async () => {
      const cached = await cacheGet<number>('pools:count');
      if (cached !== null) return cached;
      const res = await query('SELECT COUNT(*) as cnt FROM pools');
      const count = parseInt(res.rows[0].cnt, 10);
      await cacheSet('pools:count', count, 10);
      return count;
    },

    // ── Swaps ──
    swap: async (_: any, { id }: { id: number }) => {
      const res = await query('SELECT * FROM swaps WHERE id = $1', [id]);
      return res.rows.length > 0 ? mapSwap(res.rows[0]) : null;
    },

    swaps: async (_: any, { poolId, sender, limit = 50, offset = 0 }: any) => {
      let where = 'WHERE 1=1';
      const params: any[] = [];
      let idx = 1;

      if (poolId) { where += ` AND pool_id = $${idx++}`; params.push(poolId); }
      if (sender) { where += ` AND sender = $${idx++}`; params.push(sender); }

      const countRes = await query(`SELECT COUNT(*) as cnt FROM swaps ${where}`, params);
      const total = parseInt(countRes.rows[0].cnt, 10);

      const dataRes = await query(
        `SELECT * FROM swaps ${where} ORDER BY timestamp DESC LIMIT $${idx++} OFFSET $${idx}`,
        [...params, limit, offset]
      );

      return {
        items: dataRes.rows.map(mapSwap),
        total,
        hasMore: offset + limit < total,
      };
    },

    recentSwaps: async (_: any, { poolId, limit = 20 }: any) => {
      const cacheKey = `swaps:recent:${poolId || 'all'}:${limit}`;
      const cached = await cacheGet<any[]>(cacheKey);
      if (cached) return cached;

      let sql = 'SELECT * FROM swaps';
      const params: any[] = [];
      if (poolId) { sql += ' WHERE pool_id = $1'; params.push(poolId); }
      sql += ' ORDER BY timestamp DESC LIMIT $' + (params.length + 1);
      params.push(limit);

      const res = await query(sql, params);
      const result = res.rows.map(mapSwap);
      await cacheSet(cacheKey, result, 3);
      return result;
    },

    // ── Liquidity Events ──
    liquidityEvents: async (_: any, { poolId, provider, eventType, limit = 50, offset = 0 }: any) => {
      let where = 'WHERE 1=1';
      const params: any[] = [];
      let idx = 1;

      if (poolId) { where += ` AND pool_id = $${idx++}`; params.push(poolId); }
      if (provider) { where += ` AND provider = $${idx++}`; params.push(provider); }
      if (eventType) { where += ` AND event_type = $${idx++}`; params.push(eventType); }

      const countRes = await query(`SELECT COUNT(*) as cnt FROM liquidity_events ${where}`, params);
      const total = parseInt(countRes.rows[0].cnt, 10);

      const dataRes = await query(
        `SELECT * FROM liquidity_events ${where} ORDER BY timestamp DESC LIMIT $${idx++} OFFSET $${idx}`,
        [...params, limit, offset]
      );

      return {
        items: dataRes.rows.map(mapLiqEvent),
        total,
        hasMore: offset + limit < total,
      };
    },

    // ── Fee Collections ──
    feeCollections: async (_: any, { poolId, limit = 50, offset = 0 }: any) => {
      let sql = 'SELECT * FROM fee_collections';
      const params: any[] = [];
      if (poolId) { sql += ' WHERE pool_id = $1'; params.push(poolId); }
      sql += ` ORDER BY timestamp DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
      params.push(limit, offset);
      const res = await query(sql, params);
      return res.rows.map(mapFeeCollection);
    },

    // ── Snapshots ──
    poolSnapshots: async (_: any, { poolId, limit = 100, fromTimestamp, toTimestamp }: any) => {
      let where = 'WHERE pool_id = $1';
      const params: any[] = [poolId];
      let idx = 2;

      if (fromTimestamp) { where += ` AND timestamp >= $${idx++}`; params.push(fromTimestamp); }
      if (toTimestamp) { where += ` AND timestamp <= $${idx++}`; params.push(toTimestamp); }

      const res = await query(
        `SELECT * FROM pool_snapshots ${where} ORDER BY timestamp DESC LIMIT $${idx}`,
        [...params, limit]
      );
      return res.rows.map(mapSnapshot);
    },

    // ── Analytics ──
    poolStats: async (_: any, { poolId }: { poolId: string }) => {
      const cacheKey = `stats:pool:${poolId}`;
      const cached = await cacheGet<any>(cacheKey);
      if (cached) return cached;

      const poolRes = await query('SELECT * FROM pools WHERE pool_id = $1', [poolId]);
      if (poolRes.rows.length === 0) return null;
      const p = poolRes.rows[0];

      const tradersRes = await query('SELECT COUNT(DISTINCT sender) as cnt FROM swaps WHERE pool_id = $1', [poolId]);
      const uniqueTraders = parseInt(tradersRes.rows[0].cnt, 10);

      const now = Math.floor(Date.now() / 1000);
      const dayAgo = now - 86400;
      const swaps24hRes = await query(
        'SELECT COUNT(*) as cnt, COALESCE(SUM(ABS(CAST(amount0 AS NUMERIC))),0) as vol0, COALESCE(SUM(ABS(CAST(amount1 AS NUMERIC))),0) as vol1 FROM swaps WHERE pool_id = $1 AND timestamp >= $2',
        [poolId, dayAgo]
      );
      const s24 = swaps24hRes.rows[0];

      const stats = {
        poolId,
        totalSwaps: p.total_swaps,
        totalVolume0: p.total_volume0,
        totalVolume1: p.total_volume1,
        totalFees0: p.total_fees0,
        totalFees1: p.total_fees1,
        lpCount: p.lp_count,
        uniqueTraders,
        swaps24h: parseInt(s24.cnt, 10),
        volume0_24h: s24.vol0.toString(),
        volume1_24h: s24.vol1.toString(),
      };
      await cacheSet(cacheKey, stats, 15);
      return stats;
    },

    topTraders: async (_: any, { poolId, limit = 10 }: any) => {
      let where = '';
      const params: any[] = [];
      if (poolId) { where = 'WHERE pool_id = $1'; params.push(poolId); }
      const res = await query(
        `SELECT sender as address, COUNT(*) as swap_count,
                SUM(ABS(CAST(amount0 AS NUMERIC))) as total_volume0,
                SUM(ABS(CAST(amount1 AS NUMERIC))) as total_volume1
         FROM swaps ${where}
         GROUP BY sender ORDER BY swap_count DESC LIMIT $${params.length + 1}`,
        [...params, limit]
      );
      return res.rows.map((r: any) => ({
        address: r.address,
        swapCount: parseInt(r.swap_count, 10),
        totalVolume0: r.total_volume0.toString(),
        totalVolume1: r.total_volume1.toString(),
      }));
    },

    topLPs: async (_: any, { poolId, limit = 10 }: any) => {
      let where = "WHERE event_type = 'add'";
      const params: any[] = [];
      if (poolId) { where += ' AND pool_id = $1'; params.push(poolId); }
      const res = await query(
        `SELECT provider as address, COUNT(*) as event_count,
                SUM(CAST(amount0 AS NUMERIC)) as total_amount0,
                SUM(CAST(amount1 AS NUMERIC)) as total_amount1
         FROM liquidity_events ${where}
         GROUP BY provider ORDER BY total_amount0 DESC LIMIT $${params.length + 1}`,
        [...params, limit]
      );
      return res.rows.map((r: any) => ({
        address: r.address,
        eventCount: parseInt(r.event_count, 10),
        totalAmount0: r.total_amount0.toString(),
        totalAmount1: r.total_amount1.toString(),
      }));
    },

    priceCandles: async (_: any, { poolId, interval, from, to }: any) => {
      const res = await query(
        `SELECT
           (timestamp / $2) * $2 as bucket,
           (array_agg(sqrt_price_after ORDER BY timestamp ASC))[1] as open,
           MAX(sqrt_price_after) as high,
           MIN(sqrt_price_after) as low,
           (array_agg(sqrt_price_after ORDER BY timestamp DESC))[1] as close,
           SUM(ABS(CAST(amount0 AS NUMERIC))) as volume0,
           SUM(ABS(CAST(amount1 AS NUMERIC))) as volume1,
           COUNT(*) as swap_count
         FROM swaps
         WHERE pool_id = $1 AND timestamp >= $3 AND timestamp <= $4
         GROUP BY bucket ORDER BY bucket ASC`,
        [poolId, interval, from, to]
      );
      return res.rows.map((r: any) => ({
        timestamp: parseInt(r.bucket, 10),
        open: r.open,
        high: r.high,
        low: r.low,
        close: r.close,
        volume0: r.volume0.toString(),
        volume1: r.volume1.toString(),
        swapCount: parseInt(r.swap_count, 10),
      }));
    },

    // ── System ──
    indexerStatus: async (_: any, __: any, context: any) => {
      const cached = await cacheGet<any>('indexer:status');
      if (cached) return cached;

      const stateRes = await query("SELECT value FROM indexer_state WHERE key = 'last_block'");
      const lastIndexedBlock = stateRes.rows.length > 0 ? parseInt(stateRes.rows[0].value, 10) : 0;

      const poolCountRes = await query('SELECT COUNT(*) as cnt FROM pools');
      const poolCount = parseInt(poolCountRes.rows[0].cnt, 10);

      const swapCountRes = await query('SELECT COUNT(*) as cnt FROM swaps');
      const totalSwaps = parseInt(swapCountRes.rows[0].cnt, 10);

      let latestBlock = 0;
      if (context?.indexer) {
        try {
          const status = await context.indexer.getStatus();
          latestBlock = status.latestBlock;
        } catch { /* ignore */ }
      }

      const result = {
        lastIndexedBlock,
        latestBlock,
        behind: latestBlock - lastIndexedBlock,
        poolCount,
        totalSwaps,
      };
      await cacheSet('indexer:status', result, 5);
      return result;
    },
  },
};
