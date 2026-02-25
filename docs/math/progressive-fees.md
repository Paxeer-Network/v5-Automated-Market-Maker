<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>


# Progressive Fee Structure

## Fee Formula

The v5-ASAMM protocol implements a quadratic progressive fee that scales with trade size relative to pool liquidity:

```
fee(x) = baseFee + impactFee * (x / L)^2
```

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| baseFee | Minimum fee charged on every trade (bps) | 30 (0.30%) |
| impactFee (maxImpactFee) | Maximum additional fee for large trades (bps) | 100 (1.00%) |
| x | Absolute trade size in token units | -- |
| L | Total pool liquidity | -- |

### Fee Schedule

| Trade Size (% of pool) | Base Fee | Impact Fee | Total Fee |
|------------------------|----------|------------|-----------|
| 0.01% | 0.30% | ~0.000001% | ~0.30% |
| 0.1% | 0.30% | ~0.0001% | ~0.30% |
| 1% | 0.30% | ~0.01% | ~0.31% |
| 5% | 0.30% | ~0.25% | ~0.55% |
| 10% | 0.30% | ~1.00% | ~1.30% |
| 25% | 0.30% | ~6.25% | ~6.55% |
| 50% | 0.30% | ~25.00% | ~25.30% |

## Fee Distribution

Collected fees are split three ways:

| Recipient | Share | Purpose |
|-----------|-------|---------|
| LP providers | 70% (7000 bps) | Distributed proportional to liquidity, weighted by loyalty multiplier |
| Protocol treasury | 20% (2000 bps) | Governance-controlled, funds development and insurance |
| Trader reward pool | 10% (1000 bps) | Epoch-based rebates for consistent small traders |

### Fee Distribution in Code

The fee split is defined in `FeeConfig`:

```solidity
struct FeeConfig {
    uint256 baseFee;          // Base fee in basis points
    uint256 maxImpactFee;     // Maximum impact fee in basis points
    uint256 lpShareBps;       // LP share (default: 7000 = 70%)
    uint256 protocolShareBps; // Protocol share (default: 2000 = 20%)
    uint256 traderShareBps;   // Trader rebate pool (default: 1000 = 10%)
}
```

## LP Loyalty Multiplier

Long-term LPs earn enhanced fee shares via a combined time and volume multiplier:

```
multiplier = time_factor * sqrt(volume_factor)
```

### Time Factor

| Duration Staked | Factor |
|----------------|--------|
| 0 - 30 days | 1.00x |
| 30 - 90 days | 1.25x |
| 90 - 180 days | 1.50x |
| 180+ days | 2.00x |

### Volume Factor

```
volume_factor = min(lp_liquidity / average_lp_liquidity, 3.0)
```

Capped at 3x to prevent plutocratic dominance.

### Multiplier Examples

| LP Duration | Relative Size | Multiplier |
|-------------|--------------|------------|
| 10 days | 1x average | 1.00 * 1.00 = 1.00x |
| 60 days | 1x average | 1.25 * 1.00 = 1.25x |
| 120 days | 2x average | 1.50 * 1.41 = 2.12x |
| 200 days | 3x average | 2.00 * 1.73 = 3.46x |

## Trader Rebates

### Epoch System

- **Epoch duration**: 7 days (configurable)
- **Qualification**: Minimum N swaps per epoch (default: 5), each below whale threshold
- **Rebate pool**: 10% of all fees collected during the epoch
- **Distribution**: Proportional to qualifying trade volume

### Rebate Qualification

Trades qualify for rebates if:
1. Trade size is below `maxTradeSizeBps` of pool liquidity (default: 5%)
2. Trader has made at least `minSwapsForRebate` qualifying trades in the epoch

### Rebate Calculation

```
trader_rebate = (trader_qualifying_volume / total_qualifying_volume) * rebate_pool
```

## Anti-MEV Properties

The progressive fee structure provides natural MEV resistance:

1. **Sandwich attacks**: The attacker's front-run trade faces quadratic fees, making the attack unprofitable for most sizes
2. **JIT liquidity**: Loyalty multipliers reward long-term LPs over just-in-time providers
3. **Flash loan manipulation**: Large instant trades face both sigmoid price impact AND quadratic fees
```

---

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
