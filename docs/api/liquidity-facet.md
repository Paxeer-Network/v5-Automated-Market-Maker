<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# LiquidityFacet API Reference

The LiquidityFacet manages liquidity positions, including adding/removing liquidity and collecting earned fees.

## Functions

### addLiquidity

Add liquidity to a pool within a tick range.

```solidity
function addLiquidity(AddLiquidityParams calldata params)
    external returns (uint256 positionId, uint128 liquidity, uint256 amount0, uint256 amount1)
```

**Parameters (AddLiquidityParams):**

| Name | Type | Description |
|------|------|-------------|
| poolId | bytes32 | Target pool |
| tickLower | int24 | Lower tick bound |
| tickUpper | int24 | Upper tick bound |
| amount0Desired | uint256 | Maximum token0 to deposit |
| amount1Desired | uint256 | Maximum token1 to deposit |
| amount0Min | uint256 | Minimum token0 (slippage protection) |
| amount1Min | uint256 | Minimum token1 (slippage protection) |
| recipient | address | Position owner |
| deadline | uint256 | Transaction deadline |

**Returns:**

| Field | Type | Description |
|-------|------|-------------|
| positionId | uint256 | Unique position identifier |
| liquidity | uint128 | Liquidity minted |
| amount0 | uint256 | Actual token0 deposited |
| amount1 | uint256 | Actual token1 deposited |

### removeLiquidity

Remove liquidity from a position.

```solidity
function removeLiquidity(RemoveLiquidityParams calldata params)
    external returns (uint256 amount0, uint256 amount1)
```

**Parameters (RemoveLiquidityParams):**

| Name | Type | Description |
|------|------|-------------|
| poolId | bytes32 | Target pool |
| positionId | uint256 | Position to remove from |
| liquidityAmount | uint128 | Amount of liquidity to remove |
| amount0Min | uint256 | Minimum token0 to receive |
| amount1Min | uint256 | Minimum token1 to receive |
| recipient | address | Token recipient |
| deadline | uint256 | Transaction deadline |

### collectFees

Collect accumulated fees for a position.

```solidity
function collectFees(bytes32 poolId, uint256 positionId, address recipient)
    external returns (uint256 amount0, uint256 amount1)
```

### getPosition

Get position details.

```solidity
function getPosition(uint256 positionId) external view returns (Position memory)
```

**Returns (Position):**

| Field | Type | Description |
|-------|------|-------------|
| poolId | bytes32 | Pool the position belongs to |
| owner | address | Position owner |
| tickLower | int24 | Lower tick bound |
| tickUpper | int24 | Upper tick bound |
| liquidity | uint128 | Current liquidity |
| feeGrowthInside0LastX128 | uint256 | Fee growth checkpoint (token0) |
| feeGrowthInside1LastX128 | uint256 | Fee growth checkpoint (token1) |
| tokensOwed0 | uint256 | Uncollected fees (token0) |
| tokensOwed1 | uint256 | Uncollected fees (token1) |
| depositTimestamp | uint256 | When position was created |
| cumulativeVolume | uint256 | Volume attributed to this position |

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
