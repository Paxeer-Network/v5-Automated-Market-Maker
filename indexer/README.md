<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# v5-ASAMM Indexer

Event indexer and GraphQL API for the v5-ASAMM protocol. Designed for Railway deployment with PostgreSQL and Redis.

## Architecture

```
EventEmitter (on-chain) → Indexer (polls logs) → PostgreSQL (storage)
                                                → Redis (cache + pub/sub)
                                                → Apollo GraphQL API
```

## Railway Deployment

1. Create a new Railway project
2. Add **PostgreSQL** and **Redis** services
3. Add this directory as a service (Dockerfile)
4. Railway auto-injects `DATABASE_URL` and `REDIS_URL`
5. Set these env vars:

```
RPC_URL=https://public-rpc.paxeer.app/rpc
EVENT_EMITTER_ADDRESS=0x3FCa66c12B99e395619EE4d0aeabC2339F97E1FF
CHAIN_ID=125
START_BLOCK=0
POLL_INTERVAL_MS=3000
BATCH_SIZE=1000
PORT=4000
```

## Local Development

```bash
cp .env.example .env
# Edit .env with your local PostgreSQL and Redis URLs
npm install
npm run migrate
npm run dev
```

## GraphQL API

Endpoint: `POST /graphql`

### Example Queries

```graphql
# Get all pools
query { pools(limit: 10) { poolId token0 token1 totalSwaps reserve0 reserve1 } }

# Get pool stats with 24h analytics
query { poolStats(poolId: "0x...") { totalSwaps totalVolume0 uniqueTraders swaps24h volume0_24h } }

# Recent swaps
query { recentSwaps(poolId: "0x...", limit: 20) { sender amount0 amount1 feeAmount timestamp txHash } }

# Top traders
query { topTraders(limit: 10) { address swapCount totalVolume0 } }

# Price candles (1h intervals)
query { priceCandles(poolId: "0x...", interval: 3600, from: 1700000000, to: 1700086400) { timestamp open high low close volume0 swapCount } }

# Indexer status
query { indexerStatus { lastIndexedBlock latestBlock behind poolCount totalSwaps } }
```

## Health Check

`GET /health` returns indexer status JSON.

---

## License

Licensed under the **GNU General Public License v3.0**--see [LICENSE](../LICENSE) for terms.

```
Copyright (C) 2026 PaxLabs Inc.
SPDX-License-Identifier: GPL-3.0-only
```

## Contact & Resources

| Resource | Link |
|----------|------|
| **Protocol Documentation** | [docs.hyperpaxeer.com](https://docs.hyperpaxeer.com) |
| **Block Explorer** | [paxscan.paxeer.app](https://paxscan.paxeer.app) |
| **Sidiora Exchange** | [app.hyperpaxeer.com](https://sidiora.hyperpaxeer.com) |
| **Website** | [paxeer.app](https://paxeer.app) |
| **Twitter/X** | [@paxeer_app](https://x.com/paxeer_app) |
| **General Inquiries** | [infopaxeer@paxeer.app](mailto:infopaxeer@paxeer.app) |
| **Security Reports** | [security@paxeer.app](mailto:security@paxeer.app) |
