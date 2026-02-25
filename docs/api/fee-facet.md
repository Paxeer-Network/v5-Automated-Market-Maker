<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# FeeFacet API Reference

The FeeFacet handles progressive fee calculation, fee configuration, and protocol fee collection.

## Functions

### calculateFee

Calculate the progressive fee for a given trade size.

```solidity
function calculateFee(bytes32 poolId, uint256 tradeSize) external view returns (uint256 feeBps)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| poolId | bytes32 | The pool identifier |
| tradeSize | uint256 | Absolute trade size in token units |

**Returns:** uint256 feeBps - total fee in basis points

### setFeeConfig

Update fee configuration for a pool (owner only).

```solidity
function setFeeConfig(bytes32 poolId, FeeConfig calldata config) external
```

**Parameters (FeeConfig):**

| Name | Type | Description |
|------|------|-------------|
| baseFee | uint256 | Base fee in basis points |
| maxImpactFee | uint256 | Maximum impact fee in basis points |
| lpShareBps | uint256 | LP share (default: 7000 = 70%) |
| protocolShareBps | uint256 | Protocol share (default: 2000 = 20%) |
| traderShareBps | uint256 | Trader rebate pool (default: 1000 = 10%) |

Shares must sum to 10000 (100%).

### collectProtocolFees

Collect accumulated protocol fees.

```solidity
function collectProtocolFees(bytes32 poolId, address recipient) 
    external returns (uint256 amount0, uint256 amount1)
```

### getFeeConfig

Get current fee configuration for a pool.

```solidity
function getFeeConfig(bytes32 poolId) external view returns (FeeConfig memory)
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
