<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# PoolFacet API Reference

The PoolFacet manages pool creation, initialization, and state queries. Pool creation is **permissionless** -- anyone can create a pool.

## Functions

### createPool

Creates a new liquidity pool. Permissionless -- no owner restriction.

```solidity
function createPool(PoolConfig calldata config) external returns (bytes32 poolId)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| config.token0 | address | First token address (will be sorted) |
| config.token1 | address | Second token address (will be sorted) |
| config.poolType | PoolType | 0 = Standard, 1 = OraclePegged |
| config.tickSpacing | uint24 | Tick spacing (1 - 16384) |
| config.sigmoidAlpha | uint256 | Sigmoid steepness parameter (Q128.128) |
| config.sigmoidK | uint256 | Max deviation factor (Q128.128) |
| config.baseFee | uint256 | Base fee in basis points (max 10000) |
| config.maxImpactFee | uint256 | Max impact fee in basis points (max 10000) |

**Returns:** bytes32 poolId - unique identifier for the pool

**Events:** PoolCreated, PoolCreatedDetailed (via EventEmitter)

**Reverts:**
- "PoolFacet: invalid tick spacing" - tickSpacing is 0 or > 16384
- "PoolFacet: baseFee > 100%" - baseFee exceeds 10000 bps
- "PoolFacet: maxImpactFee > 100%" - maxImpactFee exceeds 10000 bps
- "PoolAlreadyExists" - pool with same tokens and tickSpacing exists

### initializePool

Sets the initial price for a pool.

```solidity
function initializePool(bytes32 poolId, uint160 sqrtPriceX96) external
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| poolId | bytes32 | The pool identifier |
| sqrtPriceX96 | uint160 | Initial sqrt price in Q64.96 format |

**Reverts:**
- "PoolNotFound" - pool does not exist
- "PoolAlreadyInitialized" - pool is already initialized

### getPoolState

Returns the current state of a pool.

```solidity
function getPoolState(bytes32 poolId) external view returns (PoolState memory)
```

**Returns:**

| Field | Type | Description |
|-------|------|-------------|
| sqrtPriceX96 | uint160 | Current sqrt price |
| currentTick | int24 | Current tick index |
| liquidity | uint128 | Active liquidity |
| reserve0 | uint256 | Token0 reserves |
| reserve1 | uint256 | Token1 reserves |
| feeGrowthGlobal0X128 | uint256 | Cumulative fee growth for token0 |
| feeGrowthGlobal1X128 | uint256 | Cumulative fee growth for token1 |
| protocolFees0 | uint256 | Uncollected protocol fees (token0) |
| protocolFees1 | uint256 | Uncollected protocol fees (token1) |
| lastObservationTimestamp | uint32 | Last oracle observation timestamp |
| initialized | bool | Whether the pool has been initialized |

### computePoolId

Computes the deterministic pool ID from token pair and tick spacing.

```solidity
function computePoolId(address token0, address token1, uint24 tickSpacing) 
    external pure returns (bytes32)
```

Tokens are automatically sorted, so order does not matter.

### poolExists

Checks if a pool exists.

```solidity
function poolExists(bytes32 poolId) external view returns (bool)
```

### getPoolCount

Returns the total number of pools.

```solidity
function getPoolCount() external view returns (uint256)
```

### getPoolConfig

Returns the configuration of a pool.

```solidity
function getPoolConfig(bytes32 poolId) external view returns (PoolConfig memory)
```

### getAllPoolIds

Returns all pool IDs.

```solidity
function getAllPoolIds() external view returns (bytes32[] memory)
```

### pause / unpause

Emergency pause/unpause (owner only).

```solidity
function pause() external
function unpause() external
```

### setEventEmitter

Sets the EventEmitter contract address (owner only).

```solidity
function setEventEmitter(address emitter) external
```

### getPoolCreator

Returns the address that created a pool.

```solidity
function getPoolCreator(bytes32 poolId) external view returns (address)
```
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
