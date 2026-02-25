<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>


# OracleFacet API Reference

The OracleFacet maintains an internal TWAP (Time-Weighted Average Price) oracle using a ring buffer of price observations.

## Functions

### consultTWAP

Get the time-weighted average tick over a period.

```solidity
function consultTWAP(bytes32 poolId, uint32 period) external view returns (int24 arithmeticMeanTick)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| poolId | bytes32 | Pool identifier |
| period | uint32 | Lookback period in seconds |

### getSpotTick

Get the current spot tick.

```solidity
function getSpotTick(bytes32 poolId) external view returns (int24 tick)
```

### observe

Get historical tick cumulative values at specific timestamps.

```solidity
function observe(bytes32 poolId, uint32[] calldata secondsAgos)
    external view returns (int56[] memory tickCumulatives)
```

### increaseObservationCardinalityNext

Expand the observation buffer capacity to store more historical data.

```solidity
function increaseObservationCardinalityNext(bytes32 poolId, uint16 observationCardinalityNext) external
```

## How TWAP Works

1. Every swap records an observation: (timestamp, tickCumulative, secondsPerLiquidityCumulative)
2. tickCumulative += currentTick * elapsed_seconds
3. TWAP over period T: arithmeticMeanTick = (tickCumNow - tickCumTAgo) / T
4. Ring buffer stores up to 65535 observations (expandable)

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
