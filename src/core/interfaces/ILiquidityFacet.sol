// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title ILiquidityFacet — Interface for liquidity management
/// @notice Add and remove liquidity from pools, with position tracking
interface ILiquidityFacet {
    struct AddLiquidityParams {
        bytes32 poolId;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct RemoveLiquidityParams {
        bytes32 poolId;
        uint256 positionId;
        uint128 liquidityAmount;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct Position {
        bytes32 poolId;
        address owner;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint256 tokensOwed0;
        uint256 tokensOwed1;
        uint256 depositTimestamp;
        uint256 cumulativeVolume;
    }

    event LiquidityAdded(
        bytes32 indexed poolId,
        address indexed owner,
        uint256 indexed positionId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    event LiquidityRemoved(
        bytes32 indexed poolId,
        address indexed owner,
        uint256 indexed positionId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    event FeesCollected(
        bytes32 indexed poolId,
        address indexed owner,
        uint256 indexed positionId,
        uint256 amount0,
        uint256 amount1
    );

    function addLiquidity(AddLiquidityParams calldata params)
        external
        returns (uint256 positionId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        returns (uint256 amount0, uint256 amount1);

    function collectFees(bytes32 poolId, uint256 positionId, address recipient)
        external
        returns (uint256 amount0, uint256 amount1);

    function getPosition(uint256 positionId) external view returns (Position memory);
}
