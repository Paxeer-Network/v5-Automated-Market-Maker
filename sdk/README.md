<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# @paxeer-network/v5-asamm/sdk

TypeScript SDK for the v5-ASAMM Protocol. Provides typed contract interfaces, deployment addresses, ABIs, and a convenience client for frontend integration.

## Installation

```bash
npm install @paxeer-network/v5-asamm/sdk ethers
```

## Quick Start

```typescript
import { ASAMMClient } from '@paxeer-network/v5-asamm/sdk';
import { ethers } from 'ethers';

const provider = new ethers.JsonRpcProvider('https://public-rpc.paxeer.app/rpc');
const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

const client = new ASAMMClient({
  signerOrProvider: signer,
  chainId: 125,
});

// Query pool state
const state = await client.getPoolState(poolId);
console.log('Price:', state.sqrtPriceX96);
console.log('Liquidity:', state.liquidity);

// Execute a swap
const swap = client.swap();
const result = await swap.swap({
  poolId,
  zeroForOne: true,
  amountSpecified: ethers.parseEther('10'),
  sqrtPriceLimitX96: 0n,
  recipient: signer.address,
  deadline: Math.floor(Date.now() / 1000) + 300,
});

// Get a quote without executing
const quote = await client.quoteSwap({
  tokenIn: token0,
  tokenOut: token1,
  tickSpacing: 60,
  amountIn: ethers.parseEther('10'),
});
```

## Facet Accessors

```typescript
client.pool()       // PoolFacet - create pools, query state
client.swap()       // SwapFacet - execute swaps
client.liquidity()  // LiquidityFacet - add/remove liquidity
client.fee()        // FeeFacet - fee config and collection
client.oracle()     // OracleFacet - TWAP oracle
client.oraclePeg()  // OraclePegFacet - oracle-pegged pools
client.order()      // OrderFacet - limit/stop orders
client.reward()     // RewardFacet - LP rewards, trader rebates
client.flashLoan()  // FlashLoanFacet - flash loans
client.router()     // Router - multi-hop swaps
client.quoter()     // Quoter - off-chain quotes
client.eventEmitter() // EventEmitter - query on-chain stats
```

## Using ABIs Directly

```typescript
import { DiamondABI, EventEmitterABI, PAXEER_ADDRESSES } from '@paxeer-network/v5-asamm/sdk';
import { ethers } from 'ethers';

const diamond = new ethers.Contract(PAXEER_ADDRESSES.Diamond, DiamondABI, provider);
const emitter = new ethers.Contract(PAXEER_ADDRESSES.EventEmitter, EventEmitterABI, provider);
```

## Types

```typescript
import type {
  PoolConfig, PoolState, SwapParams, SwapResult,
  AddLiquidityParams, RemoveLiquidityParams, Position,
  FeeConfig, PlaceOrderParams, Order, PegConfig,
  LPRewardInfo, TraderRewardInfo,
} from '@paxeer-network/v5-asamm/sdk';

import { PoolType, OrderType, OrderStatus } from '@paxeer-network/v5-asamm/sdk';
```

## Addresses

```typescript
import { PAXEER_ADDRESSES, getAddresses } from '@paxeer-network/v5-asamm/sdk';

// Direct access
console.log(PAXEER_ADDRESSES.Diamond);
console.log(PAXEER_ADDRESSES.Router);

// By chain ID
const addrs = getAddresses(125);
```

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
