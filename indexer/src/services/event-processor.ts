import { PoolClient } from 'pg';
import { ethers } from 'ethers';
import { publish, cacheInvalidate } from '../utils/redis';

export class EventProcessor {
  async processPoolCreated(client: PoolClient, log: ethers.LogDescription, blockNumber: number, txHash: string): Promise<void> {
    const a = log.args;
    await client.query(
      `INSERT INTO pools (pool_id, creator, token0, token1, tick_spacing, pool_type, base_fee, max_impact_fee, created_at, created_block, created_tx)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       ON CONFLICT (pool_id) DO NOTHING`,
      [a.poolId, a.creator, a.token0, a.token1, Number(a.tickSpacing), Number(a.poolType),
       a.baseFee.toString(), a.maxImpactFee.toString(), Number(a.timestamp), blockNumber, txHash]
    );
    await publish('pool:created', { poolId: a.poolId, token0: a.token0, token1: a.token1, creator: a.creator });
    await cacheInvalidate('pools:*');
  }

  async processPoolInitialized(client: PoolClient, log: ethers.LogDescription): Promise<void> {
    const a = log.args;
    await client.query(
      `UPDATE pools SET sqrt_price_x96 = $1, current_tick = $2, initialized = TRUE WHERE pool_id = $3`,
      [a.sqrtPriceX96.toString(), Number(a.tick), a.poolId]
    );
    await publish('pool:initialized', { poolId: a.poolId, sqrtPriceX96: a.sqrtPriceX96.toString(), tick: Number(a.tick) });
    await cacheInvalidate(`pool:${a.poolId}*`);
  }

  async processSwap(client: PoolClient, log: ethers.LogDescription, blockNumber: number, txHash: string, logIndex: number): Promise<void> {
    const a = log.args;
    const amt0Abs = a.amount0 > 0n ? a.amount0.toString() : (-a.amount0).toString();
    const amt1Abs = a.amount1 > 0n ? a.amount1.toString() : (-a.amount1).toString();

    await client.query(
      `INSERT INTO swaps (pool_id, sender, recipient, zero_for_one, amount0, amount1, sqrt_price_before, sqrt_price_after, tick_before, tick_after, liquidity, fee_amount, timestamp, block_number, tx_hash, log_index)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)`,
      [a.poolId, a.sender, a.recipient, a.zeroForOne, a.amount0.toString(), a.amount1.toString(),
       a.sqrtPriceX96Before.toString(), a.sqrtPriceX96After.toString(), Number(a.tickBefore), Number(a.tickAfter),
       a.liquidity.toString(), a.feeAmount.toString(), Number(a.timestamp), blockNumber, txHash, logIndex]
    );

    await client.query(
      `UPDATE pools SET sqrt_price_x96 = $1, current_tick = $2,
         total_swaps = total_swaps + 1,
         total_volume0 = (CAST(total_volume0 AS NUMERIC) + $3)::TEXT,
         total_volume1 = (CAST(total_volume1 AS NUMERIC) + $4)::TEXT,
         total_fees0 = (CAST(total_fees0 AS NUMERIC) + $5)::TEXT
       WHERE pool_id = $6`,
      [a.sqrtPriceX96After.toString(), Number(a.tickAfter), amt0Abs, amt1Abs, a.feeAmount.toString(), a.poolId]
    );

    await publish('swap', { poolId: a.poolId, zeroForOne: a.zeroForOne, amount0: a.amount0.toString(), amount1: a.amount1.toString(), fee: a.feeAmount.toString() });
    await cacheInvalidate(`pool:${a.poolId}*`);
    await cacheInvalidate('stats:*');
  }

  async processLiquidityAdded(client: PoolClient, log: ethers.LogDescription, blockNumber: number, txHash: string, logIndex: number): Promise<void> {
    const a = log.args;
    await client.query(
      `INSERT INTO liquidity_events (pool_id, provider, position_id, event_type, tick_lower, tick_upper, liquidity, amount0, amount1, reserve0_after, reserve1_after, total_liquidity_after, timestamp, block_number, tx_hash, log_index)
       VALUES ($1,$2,$3,'add',$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)`,
      [a.poolId, a.provider, Number(a.positionId), Number(a.tickLower), Number(a.tickUpper),
       a.liquidity.toString(), a.amount0.toString(), a.amount1.toString(),
       a.reserve0After.toString(), a.reserve1After.toString(), a.totalLiquidityAfter.toString(),
       Number(a.timestamp), blockNumber, txHash, logIndex]
    );

    await client.query(
      `UPDATE pools SET reserve0 = $1, reserve1 = $2, liquidity = $3 WHERE pool_id = $4`,
      [a.reserve0After.toString(), a.reserve1After.toString(), a.totalLiquidityAfter.toString(), a.poolId]
    );

    await publish('liquidity:added', { poolId: a.poolId, provider: a.provider, amount0: a.amount0.toString(), amount1: a.amount1.toString() });
    await cacheInvalidate(`pool:${a.poolId}*`);
  }

  async processLiquidityRemoved(client: PoolClient, log: ethers.LogDescription, blockNumber: number, txHash: string, logIndex: number): Promise<void> {
    const a = log.args;
    await client.query(
      `INSERT INTO liquidity_events (pool_id, provider, position_id, event_type, tick_lower, tick_upper, liquidity, amount0, amount1, reserve0_after, reserve1_after, total_liquidity_after, timestamp, block_number, tx_hash, log_index)
       VALUES ($1,$2,$3,'remove',NULL,NULL,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
      [a.poolId, a.provider, Number(a.positionId),
       a.liquidityRemoved.toString(), a.amount0.toString(), a.amount1.toString(),
       a.reserve0After.toString(), a.reserve1After.toString(), a.totalLiquidityAfter.toString(),
       Number(a.timestamp), blockNumber, txHash, logIndex]
    );

    await client.query(
      `UPDATE pools SET reserve0 = $1, reserve1 = $2, liquidity = $3 WHERE pool_id = $4`,
      [a.reserve0After.toString(), a.reserve1After.toString(), a.totalLiquidityAfter.toString(), a.poolId]
    );

    await publish('liquidity:removed', { poolId: a.poolId, provider: a.provider });
    await cacheInvalidate(`pool:${a.poolId}*`);
  }

  async processFeesCollected(client: PoolClient, log: ethers.LogDescription, blockNumber: number, txHash: string, logIndex: number): Promise<void> {
    const a = log.args;
    await client.query(
      `INSERT INTO fee_collections (pool_id, collector, amount0, amount1, protocol_fees0_remaining, protocol_fees1_remaining, timestamp, block_number, tx_hash, log_index)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
      [a.poolId, a.collector, a.amount0.toString(), a.amount1.toString(),
       a.protocolFees0Remaining.toString(), a.protocolFees1Remaining.toString(),
       Number(a.timestamp), blockNumber, txHash, logIndex]
    );

    await publish('fees:collected', { poolId: a.poolId, collector: a.collector, amount0: a.amount0.toString(), amount1: a.amount1.toString() });
    await cacheInvalidate(`pool:${a.poolId}*`);
  }

  async processPoolSnapshot(client: PoolClient, log: ethers.LogDescription, blockNumber: number): Promise<void> {
    const a = log.args;
    await client.query(
      `INSERT INTO pool_snapshots (pool_id, sqrt_price_x96, current_tick, liquidity, reserve0, reserve1, fee_growth_global0, fee_growth_global1, timestamp, block_number)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
      [a.poolId, a.sqrtPriceX96.toString(), Number(a.currentTick), a.liquidity.toString(),
       a.reserve0.toString(), a.reserve1.toString(),
       a.feeGrowthGlobal0X128.toString(), a.feeGrowthGlobal1X128.toString(),
       Number(a.timestamp), blockNumber]
    );

    await client.query(
      `UPDATE pools SET sqrt_price_x96 = $1, current_tick = $2, liquidity = $3, reserve0 = $4, reserve1 = $5 WHERE pool_id = $6`,
      [a.sqrtPriceX96.toString(), Number(a.currentTick), a.liquidity.toString(),
       a.reserve0.toString(), a.reserve1.toString(), a.poolId]
    );
  }
}
