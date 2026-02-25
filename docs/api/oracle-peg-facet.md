<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>


# OraclePegFacet API Reference

The OraclePegFacet connects external oracle feeds to pools for wrapped/bridged assets that should trade at oracle-anchored prices.

## Functions

### setOraclePeg

Set the oracle peg configuration for a pool (owner only).

```solidity
function setOraclePeg(bytes32 poolId, PegConfig calldata config) external
```

**Parameters (PegConfig):**

| Name | Type | Description |
|------|------|-------------|
| oracleAddress | address | IASAMMOracle implementation |
| twapPeriod | uint32 | TWAP lookback period in seconds |
| maxStaleness | uint32 | Max seconds before oracle is stale |
| maxSpotDeviation | uint256 | Max spot vs TWAP deviation (bps) |

### removeOraclePeg

Remove oracle peg from a pool (owner only).

```solidity
function removeOraclePeg(bytes32 poolId) external
```

### getOracleMidPrice

Get the oracle-derived mid-price for a pegged pool.

```solidity
function getOracleMidPrice(bytes32 poolId) external view returns (uint256 midPrice, bool isValid)
```

Returns the TWAP-based mid-price and whether the data is fresh and consistent.

### getPegConfig

Get the peg configuration for a pool.

```solidity
function getPegConfig(bytes32 poolId) external view returns (PegConfig memory)
```

## Oracle Interface

External oracles must implement `IASAMMOracle`:

```solidity
interface IASAMMOracle {
    function spotPrice() external view returns (uint256 price, uint256 updatedAt);
    function twapPrice(uint32 period) external view returns (uint256 price);
}
```

## Circuit Breaker

The oracle peg includes safety mechanisms:
1. If `updatedAt` is older than `maxStaleness`, the pool pauses
2. If spot price deviates from TWAP by more than `maxSpotDeviation`, the pool flags an anomaly
3. Events are emitted for monitoring: `CircuitBreakerTriggered(poolId, reason)`

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
