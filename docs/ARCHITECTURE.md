<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# v5-ASAMM Protocol Architecture

Adaptive Sigmoid Automated Market Maker -- an AMM protocol with progressive fees, an on-chain order book, oracle-pegged pools, and Diamond Standard upgradeability.

---

## 1. Protocol Overview

v5-ASAMM introduces a **sigmoid bonding curve** that delivers near-zero slippage for small
trades while progressively punishing large (whale) trades through quadratic fee scaling. The
protocol supports two pool types, an on-chain order book with limit and stop orders, and a
loyalty-based incentive system for both LPs and traders.

### Design Goals

| Goal | Mechanism |
|------|-----------|
| Capital-efficient liquidity | Sigmoid curve concentrates effective liquidity near mid-price |
| Whale punishment | Quadratic fee scaling: `fee(x) = baseFee + impactFee * (x/L)²` |
| LP retention | Time + volume loyalty multiplier on fee share |
| Trader incentives | Fee rebates for consistent small-trade volume |
| Wrapped asset support | Oracle-pegged pools anchor price to external feed |
| Upgradeability | EIP-2535 Diamond Standard with modular facets |
| Zero external deps | Every line of Solidity is custom -- no OpenZeppelin, no Solmate |

---

## 2. Bonding Curve -- Adaptive Sigmoid

### Mathematical Model

The price impact for a trade of size `x` against a pool with liquidity `L`:

```
P(x) = P_mid * (1 + k * tanh(α * x / L))
```

| Parameter | Meaning | Typical Range |
|-----------|---------|---------------|
| `P_mid` | Current mid-price (from reserves or oracle) | -- |
| `k` | Max price deviation factor | 0.5 – 2.0 |
| `α` (alpha) | Steepness -- how fast slippage grows | 1.0 – 10.0 |
| `x` | Signed trade size (+ buy, − sell) | -- |
| `L` | Total pool liquidity in the traded token | -- |

### Behavior

- **Small trades** (`x/L` ≈ 0): `tanh(αx/L) ≈ αx/L` → linear, minimal slippage
- **Medium trades**: Smooth sigmoid transition -- predictable, competitive
- **Large trades** (`x/L` → large): `tanh` saturates at ±1, but **fees scale quadratically**

### On-Chain Implementation

The `tanh` function is approximated using a rational Padé approximant in Q128.128
fixed-point arithmetic:

```
tanh(x) ≈ x * (135135 + x² * (17325 + x² * (378 + x²)))
           / (135135 + x² * (62370 + x² * (3150 + 28 * x²)))
```

This gives <0.0001% error for |x| < 4, which covers all practical trade sizes.

---

## 3. Pool Types

### 3.1 Standard Pool

- `P_mid` derived from reserve ratio: `P_mid = reserve1 / reserve0`
- Sigmoid curve applied around this derived mid-price
- Suitable for any token pair

### 3.2 Oracle-Pegged Pool

- `P_mid` anchored to an external oracle feed
- Designed for wrapped/bridged assets (WBTC, wETH, stETH, etc.)
- Reserves can be imbalanced -- price stays at oracle level
- LPs earn fees without impermanent loss from peg drift

**Oracle Interface** (`IASAMMOracle`):

```solidity
interface IASAMMOracle {
    function spotPrice() external view returns (uint256 price, uint256 updatedAt);
    function twapPrice(uint32 period) external view returns (uint256 price);
}
```

- Pool uses **TWAP** as the primary anchor for `P_mid`
- **Spot** price used as sanity check (if spot deviates >X% from TWAP, flag anomaly)
- **Circuit breaker**: if `updatedAt` is older than `maxStaleness`, pool pauses

---

## 4. Progressive Fee Structure

### Fee Formula

```
fee(x) = baseFee + impactFee * (x / L)²
```

| Trade Size (% of pool) | Effective Fee |
|------------------------|---------------|
| 0.01% | ~0.01% |
| 0.1% | ~0.02% |
| 1% | ~0.11% |
| 5% | ~2.5% |
| 10% | ~10.0% |

### Fee Distribution

| Recipient | Share | Purpose |
|-----------|-------|---------|
| LP providers | 70% | Weighted by loyalty multiplier |
| Protocol treasury | 20% | Governance-controlled |
| Trader reward pool | 10% | Rebates for consistent small traders |

---

## 5. Incentive System

### LP Loyalty Multiplier

```
multiplier = time_factor * sqrt(volume_factor)
```

**Time factor:**

| Duration | Factor |
|----------|--------|
| 0–30 days | 1.00x |
| 30–90 days | 1.25x |
| 90–180 days | 1.50x |
| 180+ days | 2.00x |

**Volume factor:** `min(lp_liquidity / average_lp_liquidity, 3.0)` -- capped at 3x to
prevent plutocratic dominance.

### Trader Rebates

- Epoch: 7 days (configurable)
- Traders with ≥N swaps per epoch (each below whale threshold) qualify for rebates
- Rebate pool: 10% of all fees collected in the epoch
- Distribution: proportional to qualifying trade volume

---

## 6. Order System

### Order Types

| Type | Trigger | Execution |
|------|---------|-----------|
| **Limit Order** | Pool price reaches target tick | Fills during swap traversal or keeper call |
| **Stop Order** | Oracle price crosses threshold | Executes as market swap at current pool price |

### Tick-Aligned Bucket Architecture

Orders snap to discrete price ticks. Each tick has a FIFO queue of orders:

```
Tick -200: [Order_A, Order_B]
Tick -100: [Order_C]
Tick    0: (current price)
Tick +100: [Order_D, Order_E, Order_F]
Tick +200: [Order_G]
```

**Properties:**
- O(1) execution when swap crosses a tick (drain the bucket)
- O(1) insertion (append to bucket queue)
- Partial fills tracked per order
- Orders expire after configurable TTL (default: 30 days)
- Minimum order size to prevent spam
- Keeper bounty: 0.01% of order value for external execution

---

## 7. Diamond Standard (EIP-2535)

### Why Diamond?

- **Modular upgrades**: Replace one facet without redeploying everything
- **No storage collisions**: Single `AppStorage` struct in a known diamond slot
- **Contract size**: Each facet stays under 24KB limit independently
- **Introspection**: `DiamondLoupeFacet` lets anyone query available functions

### Storage Pattern

All state lives in a single `AppStorage` struct stored at a deterministic storage slot:

```solidity
bytes32 constant APP_STORAGE_POSITION = keccak256("v5asamm.app.storage");

struct AppStorage {
    // Pool state
    mapping(bytes32 => Pool) pools;
    uint256 poolCount;

    // Order book
    mapping(bytes32 => mapping(int24 => OrderBucket)) orderBuckets;

    // Rewards
    mapping(address => LPRewardState) lpRewards;
    mapping(address => TraderRewardState) traderRewards;
    uint256 currentEpoch;

    // Oracle peg
    mapping(bytes32 => address) poolOracles;

    // Protocol
    address treasury;
    bool paused;
}
```

### Facet Map

```
┌─────────────────────────────────────────────────────────┐
│                    Diamond Proxy                         │
│  (fallback → delegatecall to facet by selector)          │
├─────────────────────────────────────────────────────────┤
│  BUSINESS LOGIC FACETS                                   │
│  ┌──────────┬──────────┬──────────┬───────────────┐     │
│  │SwapFacet │Liquidity │PoolFacet │FeeFacet       │     │
│  │          │Facet     │          │               │     │
│  ├──────────┼──────────┼──────────┼───────────────┤     │
│  │Oracle    │OraclePeg │Order     │RewardFacet    │     │
│  │Facet     │Facet     │Facet     │               │     │
│  ├──────────┼──────────┼──────────┼───────────────┤     │
│  │FlashLoan │          │          │               │     │
│  │Facet     │          │          │               │     │
│  └──────────┴──────────┴──────────┴───────────────┘     │
│  INFRASTRUCTURE FACETS                                   │
│  ┌──────────┬──────────┬──────────┐                     │
│  │DiamondCut│Loupe     │Ownership │                     │
│  │Facet     │Facet     │Facet     │                     │
│  └──────────┴──────────┴──────────┘                     │
└─────────────────────────────────────────────────────────┘
```

---

## 8. Periphery Contracts

Periphery contracts are stateless (or minimal state). They interact with the Diamond
via its external interface.

| Contract | Responsibility |
|----------|---------------|
| **Router** | Multi-hop swap routing, deadline + slippage protection, ETH wrapping |
| **Quoter** | Off-chain quote simulation via `staticcall` to Diamond |
| **PositionManager** | ERC-721 NFT representing LP positions. Mints/burns on add/remove liquidity |
| **OrderManager** | User-facing limit/stop order placement, cancellation, status queries |
| **PositionDescriptor** | On-chain SVG metadata generation for position NFTs |
| **Multicall** | Batch multiple calls in one transaction |
| **SelfPermit** | Gasless ERC-20 approvals via EIP-2612 permit |

---

## 9. Library Layer

All libraries are `internal` or `pure` -- no storage, no external calls.

| Library | Purpose |
|---------|---------|
| **LibDiamond** | Diamond storage, facet cut logic, selector→facet mapping |
| **LibPool** | Pool state reads/writes, pool ID computation |
| **LibSwap** | Sigmoid curve math: Padé `tanh` approximation, swap output calculation |
| **LibFee** | Quadratic fee formula, fee distribution splits |
| **LibOracle** | Internal TWAP accumulator: observation ring buffer, geometric mean |
| **LibOrder** | Tick-bucket data structures: insert, remove, drain operations |
| **LibReward** | Time+volume multiplier calculation, epoch transitions |
| **LibSecurity** | Reentrancy guard, pausable modifier, access control checks |
| **LibPosition** | LP position accounting: shares, fees owed, loyalty tracking |
| **LibTransfer** | Safe ERC-20 transfer wrappers (handles non-standard return values) |

---

## 10. Custom Utility Contracts

Zero external dependencies. Every utility is hand-written.

| Contract | Purpose |
|----------|---------|
| **FixedPointMath** | Q128.128 fixed-point arithmetic (mul, div, exp, ln) |
| **FullMath** | 512-bit multiplication (`mulDiv`) for overflow-safe math |
| **SqrtPriceMath** | Square root price conversions for tick↔price |
| **TickMath** | Tick index to/from sqrtPriceX96 conversions |
| **ERC20** | Minimal custom ERC-20 base implementation |
| **ERC721** | Minimal custom ERC-721 base (for PositionManager) |
| **ERC721Permit** | ERC-721 with EIP-4494 permit support |
| **ReentrancyGuard** | `nonReentrant` modifier using transient storage pattern |
| **Owned** | Single-owner access control |
| **Pausable** | Emergency pause/unpause with `whenNotPaused` modifier |
| **SafeTransfer** | Low-level `call`-based ERC-20 transfers with return check |

---

## 11. Directory Structure

```
src/
├── core/
│   ├── diamond/
│   │   ├── Diamond.sol
│   │   ├── DiamondCutFacet.sol
│   │   ├── DiamondLoupeFacet.sol
│   │   ├── OwnershipFacet.sol
│   │   └── InitDiamond.sol
│   ├── facets/
│   │   ├── SwapFacet.sol
│   │   ├── LiquidityFacet.sol
│   │   ├── PoolFacet.sol
│   │   ├── FeeFacet.sol
│   │   ├── OracleFacet.sol
│   │   ├── OraclePegFacet.sol
│   │   ├── OrderFacet.sol
│   │   ├── RewardFacet.sol
│   │   └── FlashLoanFacet.sol
│   ├── libraries/
│   │   ├── LibDiamond.sol
│   │   ├── LibPool.sol
│   │   ├── LibSwap.sol
│   │   ├── LibFee.sol
│   │   ├── LibOracle.sol
│   │   ├── LibOrder.sol
│   │   ├── LibReward.sol
│   │   ├── LibSecurity.sol
│   │   ├── LibPosition.sol
│   │   └── LibTransfer.sol
│   ├── storage/
│   │   └── AppStorage.sol
│   └── interfaces/
│       ├── IERC165.sol
│       ├── IERC173.sol
│       ├── IERC20.sol
│       ├── IERC20Permit.sol
│       ├── IDiamond.sol
│       ├── IDiamondCut.sol
│       ├── IDiamondLoupe.sol
│       ├── IPool.sol
│       ├── ISwapFacet.sol
│       ├── ILiquidityFacet.sol
│       ├── IFeeFacet.sol
│       ├── IOracleFacet.sol
│       ├── IASAMMOracle.sol
│       ├── IOraclePegFacet.sol
│       ├── IOrderFacet.sol
│       ├── IRewardFacet.sol
│       ├── IFlashLoanFacet.sol
│       └── IFlashLoanReceiver.sol
├── periphery/
│   ├── Router.sol
│   ├── Quoter.sol
│   ├── PositionManager.sol
│   ├── OrderManager.sol
│   ├── PositionDescriptor.sol
│   ├── Multicall.sol
│   └── SelfPermit.sol
├── tokens/
│   ├── ERC20.sol
│   ├── ERC721.sol
│   └── ERC721Permit.sol
└── utils/
    ├── Owned.sol
    ├── ReentrancyGuard.sol
    ├── Pausable.sol
    ├── FixedPointMath.sol
    ├── SafeTransfer.sol
    ├── TickMath.sol
    ├── SqrtPriceMath.sol
    └── FullMath.sol
```

---

## 12. Security Model

| Threat | Mitigation |
|--------|-----------|
| Reentrancy | Custom `ReentrancyGuard` on all state-mutating facets |
| Oracle manipulation | TWAP (not spot) as primary anchor; staleness circuit breaker |
| Flash loan attacks | Progressive fees make large instant trades prohibitively expensive |
| Sandwich attacks | Slippage protection in Router; deadline enforcement |
| Storage collision | Single `AppStorage` struct at deterministic slot (EIP-2535 pattern) |
| Facet selector clash | `DiamondCutFacet` validates no duplicate selectors on upgrade |
| Overflow | Solidity 0.8.27 checked math; `unchecked` only in proven-safe paths |
| Unauthorized upgrade | `OwnershipFacet` restricts `diamondCut` to owner (future: timelock + multisig) |

---

## 13. Gas Optimization Strategy

- **Storage packing**: Pack related fields into single 256-bit slots
- **`unchecked` blocks**: For loop counters and proven-safe arithmetic
- **`viaIR` compilation**: Enables Yul optimizer for cross-function optimization
- **Minimal proxies**: Diamond's `delegatecall` avoids code duplication
- **Tick-aligned orders**: O(1) drain during swap execution
- **Transient storage**: `ReentrancyGuard` uses EIP-1153 `tstore`/`tload` (saves ~2600 gas)

---

## 14. Upgrade Path

1. **Phase 1** (current): Owner-controlled `diamondCut`
2. **Phase 2**: Timelock (48h delay) on all facet upgrades
3. **Phase 3**: Governance token + on-chain voting for upgrades
4. **Phase 4**: Immutable -- freeze `diamondCut` permanently

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
