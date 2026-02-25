<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# SDK Integration Guide

## Installation

```bash
npm install @paxeer-network/v5-asamm/sdk
```

## Quick Start

```typescript
import { ASAMMClient, PoolFacet, SwapFacet, LiquidityFacet } from '@paxeer-network/v5-asamm/sdk';
import { ethers } from 'ethers';

// Connect to Paxeer
const provider = new ethers.JsonRpcProvider('https://public-rpc.paxeer.app/rpc');
const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

// Initialize the client
const client = new ASAMMClient({
  diamondAddress: '0x9595a92d63884d2D9924e0002D45C34d717DB291',
  signerOrProvider: signer,
  chainId: 125,
});

// Access typed facet interfaces
const pool = client.pool();       // PoolFacet
const swap = client.swap();       // SwapFacet
const liquidity = client.liquidity(); // LiquidityFacet
const fee = client.fee();         // FeeFacet
```

## Core Operations

### Create a Pool

```typescript
const tx = await pool.createPool({
  token0: '0x...tokenA',
  token1: '0x...tokenB',
  poolType: 0,           // 0 = Standard, 1 = OraclePegged
  tickSpacing: 60,
  sigmoidAlpha: ethers.parseUnits('1', 38),  // Q128.128
  sigmoidK: ethers.parseUnits('5', 37),      // Q128.128
  baseFee: 30,           // 0.30%
  maxImpactFee: 100,     // 1.00%
});
await tx.wait();

// Compute pool ID
const poolId = await pool.computePoolId(tokenA, tokenB, 60);

// Initialize at 1:1 price
await pool.initializePool(poolId, 79228162514264337593543950336n);
```

### Execute a Swap

```typescript
const result = await swap.swap({
  poolId,
  zeroForOne: true,          // token0 → token1
  amountSpecified: ethers.parseEther('10'),  // exact input
  sqrtPriceLimitX96: 0n,     // no price limit
  recipient: signer.address,
  deadline: Math.floor(Date.now() / 1000) + 3600,
});
```

### Add Liquidity

```typescript
// Approve tokens first
await token0.approve(diamondAddress, ethers.MaxUint256);
await token1.approve(diamondAddress, ethers.MaxUint256);

const { positionId, liquidity, amount0, amount1 } = await liquidity.addLiquidity({
  poolId,
  tickLower: -6000,
  tickUpper: 6000,
  amount0Desired: ethers.parseEther('1000'),
  amount1Desired: ethers.parseEther('1000'),
  amount0Min: 0n,
  amount1Min: 0n,
  recipient: signer.address,
  deadline: Math.floor(Date.now() / 1000) + 3600,
});
```

### Remove Liquidity

```typescript
await liquidity.removeLiquidity({
  poolId,
  positionId: 1,
  liquidityAmount: liquidity / 2n,
  amount0Min: 0n,
  amount1Min: 0n,
  recipient: signer.address,
  deadline: Math.floor(Date.now() / 1000) + 3600,
});
```

### Collect Fees

```typescript
const { amount0, amount1 } = await liquidity.collectFees(
  poolId,
  positionId,
  signer.address
);
```

### Query Pool State

```typescript
const state = await pool.getPoolState(poolId);
console.log('Price:', state.sqrtPriceX96);
console.log('Tick:', state.currentTick);
console.log('Liquidity:', state.liquidity);
console.log('Reserve0:', ethers.formatEther(state.reserve0));
console.log('Reserve1:', ethers.formatEther(state.reserve1));
```

## Using the Router

For production swaps with slippage protection:

```typescript
const router = client.router();

// Single-hop swap
await router.exactInputSingle({
  tokenIn: token0Address,
  tokenOut: token1Address,
  tickSpacing: 60,
  recipient: signer.address,
  deadline: Math.floor(Date.now() / 1000) + 300,
  amountIn: ethers.parseEther('10'),
  amountOutMinimum: ethers.parseEther('9.5'), // 5% slippage
  sqrtPriceLimitX96: 0n,
});
```

## Using the Quoter

Get quotes without executing:

```typescript
const quoter = client.quoter();

const quote = await quoter.quoteExactInputSingle.staticCall({
  tokenIn: token0Address,
  tokenOut: token1Address,
  tickSpacing: 60,
  amountIn: ethers.parseEther('10'),
  sqrtPriceLimitX96: 0n,
});

console.log('Expected output:', ethers.formatEther(quote.amountOut));
console.log('Price after:', quote.sqrtPriceX96After);
```

## Limit Orders

```typescript
const order = client.order();

// Place a limit buy
const orderId = await order.placeOrder({
  poolId,
  orderType: 0,           // 0 = Limit, 1 = Stop
  zeroForOne: false,       // buying token0 with token1
  targetTick: -1200,       // execute at this tick
  amount: ethers.parseEther('100'),
  expiry: 0,               // use default TTL (30 days)
});

// Check order status
const orderInfo = await order.getOrder(orderId);
console.log('Status:', orderInfo.status);
console.log('Filled:', ethers.formatEther(orderInfo.amountFilled));
```

## EventEmitter Queries

```typescript
const emitter = client.eventEmitter();

// Get all pools
const poolIds = await emitter.getAllPoolIds();

// Get pool stats
const stats = await emitter.getPoolStats(poolId);
console.log('Total swaps:', stats.totalSwaps);
console.log('Volume token0:', ethers.formatEther(stats.totalVolume0));
console.log('LPs:', stats.lpCount);

// Batch query for dashboards
const multiStats = await emitter.getMultiPoolStats(poolIds);
```

## TypeScript Types

The SDK exports all Solidity struct types as TypeScript interfaces:

```typescript
import type {
  PoolConfig,
  PoolState,
  SwapParams,
  SwapResult,
  AddLiquidityParams,
  RemoveLiquidityParams,
  Position,
  FeeConfig,
  Order,
  PlaceOrderParams,
  PegConfig,
  LPRewardInfo,
  TraderRewardInfo,
} from '@paxeer-network/v5-asamm/sdk';
```

## Contract Addresses

```typescript
import { PAXEER_ADDRESSES } from '@paxeer-network/v5-asamm/sdk';

console.log(PAXEER_ADDRESSES.Diamond);       // 0x9595...
console.log(PAXEER_ADDRESSES.Router);        // 0x635a...
console.log(PAXEER_ADDRESSES.EventEmitter);  // 0x3FCa...
```

## Error Handling

```typescript
import { ASAMMError } from '@paxeer-network/v5-asamm/sdk';

try {
  await swap.swap(params);
} catch (e) {
  if (e instanceof ASAMMError) {
    console.log('ASAMM error:', e.reason);
    console.log('Facet:', e.facet);
  }
}
```

---

## License

Licensed under the **GNU General Public License v3.0**--see [LICENSE](../../LICENSE) for terms.

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
