<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# EventEmitter API Reference

The EventEmitter is a standalone contract that emits rich events for every protocol operation and provides on-chain query functions for dashboards and indexers.

**Address**: `0x3FCa66c12B99e395619EE4d0aeabC2339F97E1FF`

## Events

### PoolCreatedDetailed

```solidity
event PoolCreatedDetailed(
    bytes32 indexed poolId,
    address indexed creator,
    address token0, address token1,
    uint24 tickSpacing, PoolType poolType,
    uint256 baseFee, uint256 maxImpactFee,
    uint256 timestamp
)
```

### SwapExecuted

```solidity
event SwapExecuted(
    bytes32 indexed poolId,
    address indexed sender,
    address indexed recipient,
    bool zeroForOne,
    int256 amount0, int256 amount1,
    uint160 sqrtPriceX96Before, uint160 sqrtPriceX96After,
    int24 tickBefore, int24 tickAfter,
    uint128 liquidity, uint256 feeAmount,
    uint256 timestamp
)
```

### LiquidityAddedDetailed

```solidity
event LiquidityAddedDetailed(
    bytes32 indexed poolId,
    address indexed provider,
    uint256 indexed positionId,
    int24 tickLower, int24 tickUpper,
    uint128 liquidity,
    uint256 amount0, uint256 amount1,
    uint256 reserve0After, uint256 reserve1After,
    uint128 totalLiquidityAfter,
    uint256 timestamp
)
```

### LiquidityRemovedDetailed

```solidity
event LiquidityRemovedDetailed(
    bytes32 indexed poolId,
    address indexed provider,
    uint256 indexed positionId,
    uint128 liquidityRemoved,
    uint256 amount0, uint256 amount1,
    uint256 reserve0After, uint256 reserve1After,
    uint128 totalLiquidityAfter,
    uint256 timestamp
)
```

### FeesCollectedDetailed

```solidity
event FeesCollectedDetailed(
    bytes32 indexed poolId,
    address indexed collector,
    uint256 amount0, uint256 amount1,
    uint256 protocolFees0Remaining, uint256 protocolFees1Remaining,
    uint256 timestamp
)
```

## Query Functions (anyone can call)

### getPoolCount
```solidity
function getPoolCount() external view returns (uint256)
```

### getAllPoolIds
```solidity
function getAllPoolIds() external view returns (bytes32[] memory)
```

### getPoolInfo
```solidity
function getPoolInfo(bytes32 poolId) external view returns (PoolInfo memory)
```

Returns: token0, token1, creator, tickSpacing, createdAt, totalSwaps, totalVolume0, totalVolume1, lastSqrtPriceX96, previousSqrtPriceX96, lastTick

### getPoolLPs
```solidity
function getPoolLPs(bytes32 poolId) external view returns (address[] memory)
```

### getPoolLPCount
```solidity
function getPoolLPCount(bytes32 poolId) external view returns (uint256)
```

### isPoolLP
```solidity
function isPoolLP(bytes32 poolId, address addr) external view returns (bool)
```

### getReserves
```solidity
function getReserves(bytes32 poolId) external view returns (uint256 reserve0, uint256 reserve1)
```

### getPrice
```solidity
function getPrice(bytes32 poolId) external view returns (uint160 sqrtPriceX96, int24 tick)
```

### getPriceChange
```solidity
function getPriceChange(bytes32 poolId) 
    external view returns (uint160 currentPrice, uint160 previousPrice, int256 priceChangeBps)
```

### getPoolStats
```solidity
function getPoolStats(bytes32 poolId) 
    external view returns (
        uint256 totalSwaps, uint256 totalVolume0, uint256 totalVolume1,
        uint256 lpCount, uint256 createdAt, address creator
    )
```

### getMultiPoolStats
```solidity
function getMultiPoolStats(bytes32[] calldata poolIds) 
    external view returns (
        uint256[] memory swapCounts, uint256[] memory volumes0,
        uint256[] memory volumes1, uint160[] memory prices
    )
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
