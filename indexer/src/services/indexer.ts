import { ethers } from 'ethers';
import { getPool } from '../utils/db';
import { EventProcessor } from './event-processor';
import { EVENT_EMITTER_ABI } from '../utils/abi';

export interface IndexerConfig {
  rpcUrl: string;
  eventEmitterAddress: string;
  pollIntervalMs: number;
  batchSize: number;
}

export class Indexer {
  private provider: ethers.JsonRpcProvider;
  private iface: ethers.Interface;
  private processor: EventProcessor;
  private config: IndexerConfig;
  private running = false;

  constructor(config: IndexerConfig) {
    this.config = config;
    this.provider = new ethers.JsonRpcProvider(config.rpcUrl);
    this.iface = new ethers.Interface(EVENT_EMITTER_ABI);
    this.processor = new EventProcessor();
  }

  async start(): Promise<void> {
    this.running = true;
    const lastBlock = await this.getLastBlock();
    console.log(`[Indexer] Starting from block ${lastBlock}`);
    console.log(`[Indexer] EventEmitter: ${this.config.eventEmitterAddress}`);
    console.log(`[Indexer] RPC: ${this.config.rpcUrl}`);
    console.log(`[Indexer] Poll interval: ${this.config.pollIntervalMs}ms, batch: ${this.config.batchSize}`);

    while (this.running) {
      try {
        await this.poll();
      } catch (err: any) {
        console.error(`[Indexer] Poll error: ${err.message}`);
      }
      await this.sleep(this.config.pollIntervalMs);
    }
  }

  stop(): void {
    this.running = false;
    console.log('[Indexer] Stopping...');
  }

  private async poll(): Promise<void> {
    const lastBlock = await this.getLastBlock();
    const currentBlock = await this.provider.getBlockNumber();
    if (lastBlock >= currentBlock) return;

    const toBlock = Math.min(lastBlock + this.config.batchSize, currentBlock);
    const logs = await this.provider.getLogs({
      address: this.config.eventEmitterAddress,
      fromBlock: lastBlock + 1,
      toBlock,
    });

    if (logs.length > 0) {
      console.log(`[Indexer] Processing ${logs.length} events (blocks ${lastBlock + 1}-${toBlock})`);
    }

    const pg = getPool();
    const client = await pg.connect();
    try {
      await client.query('BEGIN');

      for (const log of logs) {
        try {
          const parsed = this.iface.parseLog({ topics: log.topics as string[], data: log.data });
          if (!parsed) continue;

          switch (parsed.name) {
            case 'PoolCreatedDetailed':
              await this.processor.processPoolCreated(client, parsed, log.blockNumber, log.transactionHash);
              break;
            case 'PoolInitializedDetailed':
              await this.processor.processPoolInitialized(client, parsed);
              break;
            case 'SwapExecuted':
              await this.processor.processSwap(client, parsed, log.blockNumber, log.transactionHash, log.index);
              break;
            case 'LiquidityAddedDetailed':
              await this.processor.processLiquidityAdded(client, parsed, log.blockNumber, log.transactionHash, log.index);
              break;
            case 'LiquidityRemovedDetailed':
              await this.processor.processLiquidityRemoved(client, parsed, log.blockNumber, log.transactionHash, log.index);
              break;
            case 'FeesCollectedDetailed':
              await this.processor.processFeesCollected(client, parsed, log.blockNumber, log.transactionHash, log.index);
              break;
            case 'PoolSnapshot':
              await this.processor.processPoolSnapshot(client, parsed, log.blockNumber);
              break;
          }
        } catch (err: any) {
          console.error(`[Indexer] Event parse error: ${err.message}`);
        }
      }

      await client.query("UPDATE indexer_state SET value = $1 WHERE key = 'last_block'", [toBlock.toString()]);
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  private async getLastBlock(): Promise<number> {
    const res = await getPool().query("SELECT value FROM indexer_state WHERE key = 'last_block'");
    return res.rows.length > 0 ? parseInt(res.rows[0].value, 10) : 0;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async getStatus(): Promise<{ lastIndexedBlock: number; latestBlock: number; behind: number }> {
    const lastIndexedBlock = await this.getLastBlock();
    const latestBlock = await this.provider.getBlockNumber();
    return { lastIndexedBlock, latestBlock, behind: latestBlock - lastIndexedBlock };
  }
}
