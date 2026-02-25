import { getPool } from './db';
import 'dotenv/config';

const MIGRATIONS = `
  CREATE TABLE IF NOT EXISTS indexer_state (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS pools (
    pool_id TEXT PRIMARY KEY,
    creator TEXT NOT NULL,
    token0 TEXT NOT NULL,
    token1 TEXT NOT NULL,
    tick_spacing INTEGER NOT NULL,
    pool_type INTEGER NOT NULL,
    base_fee TEXT NOT NULL DEFAULT '0',
    max_impact_fee TEXT NOT NULL DEFAULT '0',
    sqrt_price_x96 TEXT DEFAULT '0',
    current_tick INTEGER DEFAULT 0,
    liquidity TEXT DEFAULT '0',
    reserve0 TEXT DEFAULT '0',
    reserve1 TEXT DEFAULT '0',
    total_swaps INTEGER DEFAULT 0,
    total_volume0 TEXT DEFAULT '0',
    total_volume1 TEXT DEFAULT '0',
    total_fees0 TEXT DEFAULT '0',
    total_fees1 TEXT DEFAULT '0',
    lp_count INTEGER DEFAULT 0,
    initialized BOOLEAN DEFAULT FALSE,
    created_at INTEGER NOT NULL,
    created_block INTEGER NOT NULL,
    created_tx TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS swaps (
    id SERIAL PRIMARY KEY,
    pool_id TEXT NOT NULL REFERENCES pools(pool_id),
    sender TEXT NOT NULL,
    recipient TEXT NOT NULL,
    zero_for_one BOOLEAN NOT NULL,
    amount0 TEXT NOT NULL,
    amount1 TEXT NOT NULL,
    sqrt_price_before TEXT NOT NULL,
    sqrt_price_after TEXT NOT NULL,
    tick_before INTEGER NOT NULL,
    tick_after INTEGER NOT NULL,
    liquidity TEXT NOT NULL,
    fee_amount TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    block_number INTEGER NOT NULL,
    tx_hash TEXT NOT NULL,
    log_index INTEGER NOT NULL
  );

  CREATE TABLE IF NOT EXISTS liquidity_events (
    id SERIAL PRIMARY KEY,
    pool_id TEXT NOT NULL REFERENCES pools(pool_id),
    provider TEXT NOT NULL,
    position_id INTEGER NOT NULL,
    event_type TEXT NOT NULL CHECK(event_type IN ('add', 'remove')),
    tick_lower INTEGER,
    tick_upper INTEGER,
    liquidity TEXT NOT NULL,
    amount0 TEXT NOT NULL,
    amount1 TEXT NOT NULL,
    reserve0_after TEXT NOT NULL,
    reserve1_after TEXT NOT NULL,
    total_liquidity_after TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    block_number INTEGER NOT NULL,
    tx_hash TEXT NOT NULL,
    log_index INTEGER NOT NULL
  );

  CREATE TABLE IF NOT EXISTS fee_collections (
    id SERIAL PRIMARY KEY,
    pool_id TEXT NOT NULL REFERENCES pools(pool_id),
    collector TEXT NOT NULL,
    amount0 TEXT NOT NULL,
    amount1 TEXT NOT NULL,
    protocol_fees0_remaining TEXT NOT NULL,
    protocol_fees1_remaining TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    block_number INTEGER NOT NULL,
    tx_hash TEXT NOT NULL,
    log_index INTEGER NOT NULL
  );

  CREATE TABLE IF NOT EXISTS pool_snapshots (
    id SERIAL PRIMARY KEY,
    pool_id TEXT NOT NULL REFERENCES pools(pool_id),
    sqrt_price_x96 TEXT NOT NULL,
    current_tick INTEGER NOT NULL,
    liquidity TEXT NOT NULL,
    reserve0 TEXT NOT NULL,
    reserve1 TEXT NOT NULL,
    fee_growth_global0 TEXT NOT NULL,
    fee_growth_global1 TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    block_number INTEGER NOT NULL
  );

  CREATE INDEX IF NOT EXISTS idx_swaps_pool ON swaps(pool_id);
  CREATE INDEX IF NOT EXISTS idx_swaps_sender ON swaps(sender);
  CREATE INDEX IF NOT EXISTS idx_swaps_recipient ON swaps(recipient);
  CREATE INDEX IF NOT EXISTS idx_swaps_timestamp ON swaps(timestamp);
  CREATE INDEX IF NOT EXISTS idx_swaps_block ON swaps(block_number);
  CREATE INDEX IF NOT EXISTS idx_liq_pool ON liquidity_events(pool_id);
  CREATE INDEX IF NOT EXISTS idx_liq_provider ON liquidity_events(provider);
  CREATE INDEX IF NOT EXISTS idx_liq_timestamp ON liquidity_events(timestamp);
  CREATE INDEX IF NOT EXISTS idx_fees_pool ON fee_collections(pool_id);
  CREATE INDEX IF NOT EXISTS idx_snapshots_pool ON pool_snapshots(pool_id);
  CREATE INDEX IF NOT EXISTS idx_snapshots_timestamp ON pool_snapshots(timestamp);
`;

export async function migrate(): Promise<void> {
  const pool = getPool();
  const client = await pool.connect();
  try {
    await client.query(MIGRATIONS);

    // Seed initial block if not present
    const res = await client.query("SELECT value FROM indexer_state WHERE key = 'last_block'");
    if (res.rows.length === 0) {
      const startBlock = process.env.START_BLOCK || '0';
      await client.query("INSERT INTO indexer_state (key, value) VALUES ('last_block', $1)", [startBlock]);
    }

    console.log('[Migrate] Schema applied successfully');
  } finally {
    client.release();
  }
}

if (require.main === module) {
  migrate()
    .then(() => { console.log('Done'); process.exit(0); })
    .catch((err) => { console.error(err); process.exit(1); });
}
