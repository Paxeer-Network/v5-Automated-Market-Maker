<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
  <img src="https://img.shields.io/badge/EIP--2535-Diamond%20Standard-orange.svg" alt="Diamond" />
</p>

# v5-ASAMM Protocol

Adaptive Sigmoid Automated Market Maker for Paxeer Network. Built with a sigmoid bonding curve, progressive fees, an on-chain order book, oracle-pegged pools, and Diamond Standard upgradeability.

## Features

| Feature | Description |
|---------|-------------|
| **Sigmoid Bonding Curve** | `tanh`-based price impact -- flat for small trades, steep for large ones |
| **Progressive Fees** | Quadratic fee scaling: `fee(x) = baseFee + impactFee * (x/L)^2` |
| **LP Loyalty Rewards** | Time + volume multiplier up to 2x fee share for long-term providers |
| **Trader Rebates** | Epoch-based fee rebates for consistent smaller-volume traders |
| **Oracle-Pegged Pools** | Wrapped assets trade at oracle price with TWAP anchor and circuit breaker |
| **On-Chain Order Book** | Tick-aligned limit and stop orders with keeper execution |
| **Diamond Standard** | EIP-2535 modular upgradeability across 12 independent facets |
| **Zero External Deps** | All Solidity is written from scratch -- no OpenZeppelin, no Solmate |

## Architecture

```
Diamond Proxy (EIP-2535)
  Core Facets: Swap, Liquidity, Pool, Fee, Oracle, OraclePeg, Order, Reward, FlashLoan
  Infrastructure: DiamondCut, DiamondLoupe, Ownership
  Libraries: LibSwap (sigmoid math), LibFee (quadratic), LibOrder (tick buckets), ...

Periphery (Stateless)
  Router         -- Multi-hop swaps with slippage protection
  Quoter         -- Off-chain quote simulation
  PositionManager -- ERC-721 NFT LP positions
  OrderManager   -- Limit/stop order placement
  Multicall      -- Batch operations
  SelfPermit     -- Gasless approvals
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full design document.

## Quick Start

```bash
npm install
npm run compile
npm test
npm run test:forge
npm run size
npm run deploy:local
```

## Project Structure

```
src/
  core/           Diamond proxy, facets, libraries, storage, interfaces
  periphery/      Router, Quoter, PositionManager, OrderManager, etc.
  tokens/         Custom ERC-20, ERC-721, ERC-721Permit
  utils/          Math, security, transfer helpers
test/             Hardhat + Foundry test suites
scripts/          Deployment and utility scripts
docs/             Protocol documentation (VitePress)
indexer/          Event indexer with GraphQL API
sdk/              TypeScript SDK for frontend integration
```

## Network

| Property | Value |
|----------|-------|
| **Chain** | Paxeer Network |
| **Chain ID** | 125 |
| **RPC** | `https://public-rpc.paxeer.app/rpc` |
| **Explorer** | [paxscan.paxeer.app](https://paxscan.paxeer.app) |

## Development

```bash
npm run lint:sol        # Solidity linting
npm run lint:ts         # TypeScript linting
npm run format          # Format code
npm run slither         # Static analysis
npm run test:gas        # Gas report
npm run test:coverage   # Coverage report
```

---

## License

Licensed under the **GNU General Public License v3.0**--see [LICENSE](LICENSE) for terms.

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
