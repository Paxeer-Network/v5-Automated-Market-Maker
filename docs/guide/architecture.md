<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# Architecture

## Overview

v5-ASAMM is built on the **Diamond Standard (EIP-2535)**, a proxy pattern that routes function calls to modular **facets** via selector-based dispatch. All state is stored in a single `AppStorage` struct at a deterministic storage slot, ensuring zero storage collisions across facets.

```
┌─────────────────────────────────────────────────────┐
│                   Diamond Proxy                      │
│  (fallback → delegatecall to facet by selector)      │
├─────────────────────────────────────────────────────┤
│  BUSINESS LOGIC FACETS                               │
│  ┌──────────┬───────────┬──────────┬──────────────┐ │
│  │SwapFacet │Liquidity  │PoolFacet │FeeFacet      │ │
│  │          │Facet      │          │              │ │
│  ├──────────┼───────────┼──────────┼──────────────┤ │
│  │Oracle    │OraclePeg  │Order     │RewardFacet   │ │
│  │Facet     │Facet      │Facet     │              │ │
│  ├──────────┼───────────┼──────────┼──────────────┤ │
│  │FlashLoan │           │          │              │ │
│  │Facet     │           │          │              │ │
│  └──────────┴───────────┴──────────┴──────────────┘ │
│  INFRASTRUCTURE FACETS                               │
│  ┌──────────┬───────────┬──────────┐                │
│  │DiamondCut│DiamondLoup│Ownership │                │
│  │Facet     │eFacet     │Facet     │                │
│  └──────────┴───────────┴──────────┘                │
│                                                      │
│  PERIPHERY (external, stateless)                     │
│  ┌──────┬────────┬────────────┬─────────────┐       │
│  │Router│Quoter  │Position    │OrderManager │       │
│  │      │        │Manager     │             │       │
│  └──────┴────────┴────────────┴─────────────┘       │
│                                                      │
│  EVENT HUB (external)                                │
│  ┌──────────────┐                                   │
│  │EventEmitter  │                                   │
│  └──────────────┘                                   │
└─────────────────────────────────────────────────────┘
```

## Storage Pattern

All facets share a single storage struct via `delegatecall`. The struct is stored at a deterministic slot computed from `keccak256("v5asamm.app.storage")`:

```solidity
struct AppStorage {
    // Pool state
    mapping(bytes32 => PoolConfig) poolConfigs;
    mapping(bytes32 => PoolState)  poolStates;
    bytes32[] poolIds;
    uint256   poolCount;

    // Positions
    mapping(uint256 => Position) positions;
    uint256 nextPositionId;

    // Tick state
    mapping(bytes32 => mapping(int24 => TickInfo)) ticks;
    mapping(bytes32 => mapping(int16 => uint256))  tickBitmaps;

    // Fee configuration
    mapping(bytes32 => FeeConfig) feeConfigs;

    // Order book
    mapping(uint256 => Order) orders;
    mapping(bytes32 => mapping(int24 => OrderBucket)) orderBuckets;
    uint256 nextOrderId;
    uint256 maxOrdersPerPool;
    uint256 defaultOrderTTL;
    uint256 minOrderSize;
    uint256 keeperBountyBps;

    // Oracle
    mapping(bytes32 => Observation[65535]) observations;
    mapping(bytes32 => ObservationState) observationStates;

    // Oracle peg
    mapping(bytes32 => PegConfig) pegConfigs;

    // Rewards
    mapping(bytes32 => mapping(address => LPRewardState)) lpRewards;
    mapping(address => TraderRewardState) traderRewards;
    uint256 currentEpoch;
    uint256 epochStartTime;
    EpochConfig epochConfig;

    // Protocol
    address treasury;
    bool    paused;
    mapping(address => bool) pauseGuardians;
    mapping(bytes32 => address) poolCreators;
    address eventEmitter;
    uint256 reentrancyStatus;
}
```

## Facet Responsibilities

### Business Logic Facets

| Facet | Selectors | Responsibility |
|-------|-----------|---------------|
| **PoolFacet** | 14 | Pool creation (permissionless), initialization, state queries, pause/unpause |
| **SwapFacet** | 1 | Sigmoid curve swap execution with progressive fees |
| **LiquidityFacet** | 4 | Add/remove liquidity, fee collection, position queries |
| **FeeFacet** | 4 | Quadratic fee calculation, fee config, protocol fee collection |
| **OracleFacet** | 4 | Internal TWAP oracle with ring buffer observations |
| **OraclePegFacet** | 4 | External oracle integration for pegged pools |
| **OrderFacet** | 6 | Limit/stop orders, tick-aligned bucket execution |
| **RewardFacet** | 6 | LP loyalty multipliers, trader epoch rebates |
| **FlashLoanFacet** | 2 | Uncollateralized flash loans with fee |

### Infrastructure Facets

| Facet | Responsibility |
|-------|---------------|
| **DiamondCutFacet** | Add, replace, remove facet selectors (owner only) |
| **DiamondLoupeFacet** | Introspection: query facets, selectors, interfaces |
| **OwnershipFacet** | ERC-173 ownership transfer |

## Periphery Contracts

Periphery contracts are **stateless** -- they interact with the Diamond via its external interface and hold no protocol state.

| Contract | Purpose |
|----------|---------|
| **Router** | Multi-hop swaps, slippage protection, deadline enforcement |
| **Quoter** | Off-chain quote simulation via `staticcall` |
| **PositionManager** | ERC-721 NFT LP positions, mint/burn lifecycle |
| **OrderManager** | User-facing order placement, cancellation, status |
| **PositionDescriptor** | On-chain SVG metadata for position NFTs |
| **Multicall** | Batch multiple calls in one transaction |
| **SelfPermit** | Gasless ERC-20 approvals via EIP-2612 |

## EventEmitter

The `EventEmitter` is a standalone contract that:
1. **Emits rich events** for every protocol operation (pools, swaps, liquidity, fees)
2. **Maintains an on-chain registry** of pools, LPs, and volume statistics
3. **Provides query functions** for dashboards and indexers

Only the Diamond can call emit functions. Anyone can call query functions.

## Library Layer

All libraries are `internal` -- they execute in the Diamond's context via `delegatecall`.

| Library | Purpose |
|---------|---------|
| **LibDiamond** | Diamond storage, selector→facet mapping, cut logic |
| **LibPool** | Pool creation, state access, token sorting, pool ID computation |
| **LibSwap** | Sigmoid math: Padé `tanh`, swap step calculation |
| **LibFee** | Quadratic fee formula, fee distribution splits |
| **LibOracle** | TWAP accumulator, observation ring buffer, geometric mean |
| **LibOrder** | Tick-bucket FIFO queue: insert, remove, drain |
| **LibReward** | Time+volume multiplier, epoch transitions |
| **LibSecurity** | Reentrancy guard, pausable, access control |
| **LibPosition** | LP position accounting, fee growth tracking |
| **LibTransfer** | Safe ERC-20 transfers (handles non-standard returns) |
| **LibTickBitmap** | Bitmap for efficient next-initialized-tick queries |
| **LibEventEmitter** | Safe external calls to EventEmitter from facets |

## Utility Contracts

Zero external dependencies -- every utility is hand-written:

| Contract | Purpose |
|----------|---------|
| **FixedPointMath** | Q128.128 fixed-point: mul, div, tanh, sqrt, min/max |
| **FullMath** | 512-bit `mulDiv` for overflow-safe intermediate products |
| **SqrtPriceMath** | Token amount deltas from sqrt price ranges |
| **TickMath** | Tick↔sqrtPriceX96 conversions |
| **ERC20** | Minimal custom ERC-20 |
| **ERC721** | Minimal custom ERC-721 |
| **ERC721Permit** | ERC-721 + EIP-4494 permit |

## Call Flow Examples

### Swap Flow
```
User → Router.exactInputSingle()
  → Diamond.swap(params)
    → SwapFacet (via delegatecall)
      → LibSecurity.nonReentrantBefore()
      → LibSwap.computeSwapStep() [sigmoid math]
      → LibFee.calculateProgressiveFee() [quadratic]
      → LibPool.updateReserves()
      → LibOracle.write() [TWAP observation]
      → LibEventEmitter.emitSwap() → EventEmitter
      → LibSecurity.nonReentrantAfter()
```

### Add Liquidity Flow
```
User → PositionManager.mint()
  → Diamond.addLiquidity(params)
    → LiquidityFacet (via delegatecall)
      → LibSecurity checks
      → LibPosition.createOrUpdate()
      → LibPool.updateLiquidity()
      → LibTransfer.safeTransferFrom() [pull tokens]
      → LibEventEmitter.emitLiquidityAdded()
```

### Pool Creation Flow
```
Anyone → Diamond.createPool(config)
  → PoolFacet (via delegatecall)
    → LibSecurity.requireNotPaused()
    → Validate tickSpacing, baseFee, maxImpactFee
    → LibPool.createPool() [sort tokens, compute ID, store config]
    → Store feeConfig, track creator
    → LibEventEmitter.emitPoolCreated()
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
