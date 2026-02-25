// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../storage/AppStorage.sol";
import "../interfaces/ILiquidityFacet.sol";
import "../../utils/FullMath.sol";

/// @title LibPosition — LP position accounting (shares, fees owed, loyalty tracking)
/// @notice Manages LP position state within AppStorage
/// @dev Custom implementation — no external dependencies
library LibPosition {
    error PositionDoesNotExist();
    error NotPositionOwner();
    error InsufficientLiquidity();

    /// @notice Create a new LP position
    /// @return positionId The newly created position ID
    function createPosition(
        bytes32 poolId,
        address owner,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal returns (uint256 positionId) {
        AppStorage storage s = LibAppStorage.appStorage();

        positionId = s.nextPositionId++;

        s.positions[positionId] = ILiquidityFacet.Position({
            poolId: poolId,
            owner: owner,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            feeGrowthInside0LastX128: feeGrowthInside0X128,
            feeGrowthInside1LastX128: feeGrowthInside1X128,
            tokensOwed0: 0,
            tokensOwed1: 0,
            depositTimestamp: block.timestamp,
            cumulativeVolume: 0
        });

        // Initialize LP reward tracking
        s.lpRewards[positionId] = LPRewardState({
            depositTimestamp: block.timestamp,
            cumulativeVolume: 0,
            lastClaimEpoch: s.epochState.currentEpoch
        });
    }

    /// @notice Update a position's liquidity (increase)
    /// @param positionId The position to update
    /// @param liquidityDelta The amount of liquidity to add
    function addLiquidity(uint256 positionId, uint128 liquidityDelta) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        ILiquidityFacet.Position storage pos = s.positions[positionId];
        if (pos.owner == address(0)) revert PositionDoesNotExist();

        pos.liquidity += liquidityDelta;
    }

    /// @notice Update a position's liquidity (decrease)
    /// @param positionId The position to update
    /// @param liquidityDelta The amount of liquidity to remove
    function removeLiquidity(uint256 positionId, uint128 liquidityDelta) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        ILiquidityFacet.Position storage pos = s.positions[positionId];
        if (pos.owner == address(0)) revert PositionDoesNotExist();
        if (pos.liquidity < liquidityDelta) revert InsufficientLiquidity();

        pos.liquidity -= liquidityDelta;
    }

    /// @notice Update fee growth checkpoints and calculate owed fees
    /// @param positionId The position to update
    /// @param feeGrowthInside0X128 Current fee growth for token0
    /// @param feeGrowthInside1X128 Current fee growth for token1
    /// @return tokensOwed0 Newly accrued fees for token0
    /// @return tokensOwed1 Newly accrued fees for token1
    function updateFees(
        uint256 positionId,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal returns (uint256 tokensOwed0, uint256 tokensOwed1) {
        AppStorage storage s = LibAppStorage.appStorage();
        ILiquidityFacet.Position storage pos = s.positions[positionId];
        if (pos.owner == address(0)) revert PositionDoesNotExist();

        // Calculate newly accrued fees
        unchecked {
            tokensOwed0 = FullMath.mulDiv(feeGrowthInside0X128 - pos.feeGrowthInside0LastX128, pos.liquidity, 1 << 128);
            tokensOwed1 = FullMath.mulDiv(feeGrowthInside1X128 - pos.feeGrowthInside1LastX128, pos.liquidity, 1 << 128);
        }

        // Update checkpoints
        pos.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        pos.feeGrowthInside1LastX128 = feeGrowthInside1X128;

        // Accumulate owed tokens
        pos.tokensOwed0 += tokensOwed0;
        pos.tokensOwed1 += tokensOwed1;
    }

    /// @notice Collect owed fees from a position
    /// @param positionId The position to collect from
    /// @return amount0 The collected amount of token0
    /// @return amount1 The collected amount of token1
    function collectFees(uint256 positionId) internal returns (uint256 amount0, uint256 amount1) {
        AppStorage storage s = LibAppStorage.appStorage();
        ILiquidityFacet.Position storage pos = s.positions[positionId];
        if (pos.owner == address(0)) revert PositionDoesNotExist();

        amount0 = pos.tokensOwed0;
        amount1 = pos.tokensOwed1;

        pos.tokensOwed0 = 0;
        pos.tokensOwed1 = 0;
    }

    /// @notice Get position details
    function getPosition(uint256 positionId) internal view returns (ILiquidityFacet.Position storage) {
        AppStorage storage s = LibAppStorage.appStorage();
        if (s.positions[positionId].owner == address(0)) revert PositionDoesNotExist();
        return s.positions[positionId];
    }

    /// @notice Check if caller is the position owner
    function enforcePositionOwner(uint256 positionId) internal view {
        AppStorage storage s = LibAppStorage.appStorage();
        if (s.positions[positionId].owner != msg.sender) revert NotPositionOwner();
    }
}
