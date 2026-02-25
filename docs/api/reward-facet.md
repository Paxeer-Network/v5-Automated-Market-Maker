<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>


# RewardFacet API Reference

The RewardFacet manages LP loyalty rewards and trader epoch-based rebates.

## Functions

### getLPMultiplier

Calculate the current loyalty multiplier for an LP position.

```solidity
function getLPMultiplier(uint256 positionId) external view returns (uint256 multiplier)
```

Returns Q128.128 multiplier. A value of 2^128 = 1.0x, 2^129 = 2.0x, etc.

### getLPRewardInfo

Get full reward info for an LP position.

```solidity
function getLPRewardInfo(uint256 positionId) external view returns (LPRewardInfo memory)
```

**Returns (LPRewardInfo):**

| Field | Type | Description |
|-------|------|-------------|
| loyaltyMultiplier | uint256 | Current multiplier (Q128.128) |
| accumulatedFees0 | uint256 | Total fees earned (token0) |
| accumulatedFees1 | uint256 | Total fees earned (token1) |
| depositTimestamp | uint256 | Position creation time |
| cumulativeVolume | uint256 | Volume attributed to position |

### getTraderRewardInfo

Get reward info for a trader.

```solidity
function getTraderRewardInfo(address trader) external view returns (TraderRewardInfo memory)
```

**Returns (TraderRewardInfo):**

| Field | Type | Description |
|-------|------|-------------|
| currentEpoch | uint256 | Current epoch number |
| epochSwapCount | uint256 | Swaps in current epoch |
| epochVolume | uint256 | Volume in current epoch |
| pendingRebate0 | uint256 | Claimable rebate (token0) |
| pendingRebate1 | uint256 | Claimable rebate (token1) |

### claimTraderRebate

Claim pending trader rebates.

```solidity
function claimTraderRebate(address recipient) external returns (uint256 amount0, uint256 amount1)
```

### advanceEpoch

Advance to the next epoch. Callable by anyone.

```solidity
function advanceEpoch() external
```

### setEpochConfig

Set epoch configuration (owner only).

```solidity
function setEpochConfig(EpochConfig calldata config) external
```

### getCurrentEpoch

Get current epoch info.

```solidity
function getCurrentEpoch() external view returns (uint256 epoch, uint256 startTime, uint256 endTime)
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
