// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title IPool — Pool data structures and pool-level queries
/// @notice Defines pool configuration and state types used across the protocol
interface IPool {
    enum PoolType {
        Standard,   // Reserve-derived P_mid
        OraclePegged // Oracle-anchored P_mid
    }

    struct PoolConfig {
        address token0;
        address token1;
        PoolType poolType;
        uint24 tickSpacing;
        uint256 sigmoidAlpha;    // Steepness parameter (Q128.128)
        uint256 sigmoidK;        // Max deviation factor (Q128.128)
        uint256 baseFee;         // Base fee in basis points (e.g., 1 = 0.01%)
        uint256 maxImpactFee;    // Max impact fee in basis points
    }

    struct PoolState {
        uint160 sqrtPriceX96;
        int24 currentTick;
        uint128 liquidity;
        uint256 reserve0;
        uint256 reserve1;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        uint256 protocolFees0;
        uint256 protocolFees1;
        uint32 lastObservationTimestamp;
        bool initialized;
    }

    event PoolCreated(
        bytes32 indexed poolId,
        address indexed token0,
        address indexed token1,
        PoolType poolType,
        uint24 tickSpacing
    );

    event PoolInitialized(bytes32 indexed poolId, uint160 sqrtPriceX96, int24 tick);
}
