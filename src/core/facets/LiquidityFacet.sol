// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../interfaces/ILiquidityFacet.sol";
import "../interfaces/IPool.sol";
import "../libraries/LibPool.sol";
import "../libraries/LibPosition.sol";
import "../libraries/LibSecurity.sol";
import "../libraries/LibTransfer.sol";
import "../libraries/LibOracle.sol";
import "../libraries/LibEventEmitter.sol";
import "../storage/AppStorage.sol";
import "../../utils/FullMath.sol";
import "../../utils/FixedPointMath.sol";

/// @title LiquidityFacet — Add/remove liquidity and collect fees
/// @notice Manages LP positions with tick-range concentration
/// @dev Diamond facet — operates on AppStorage via delegatecall
contract LiquidityFacet is ILiquidityFacet {
    /// @inheritdoc ILiquidityFacet
    function addLiquidity(
        AddLiquidityParams calldata params
    ) external returns (uint256 positionId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        LibSecurity.nonReentrantBefore();
        LibSecurity.requireNotPaused();
        LibSecurity.checkDeadline(params.deadline);

        AppStorage storage s = LibAppStorage.appStorage();
        IPool.PoolConfig storage config = s.poolConfigs[params.poolId];
        IPool.PoolState storage state = s.poolStates[params.poolId];

        require(state.initialized, "LiquidityFacet: pool not initialized");
        require(params.tickLower < params.tickUpper, "LiquidityFacet: invalid tick range");

        // Calculate liquidity from desired amounts
        // Simplified: use proportional share of reserves
        if (state.reserve0 == 0 && state.reserve1 == 0) {
            // First deposit — liquidity = sqrt(amount0 * amount1)
            liquidity = uint128(FixedPointMath.sqrt(params.amount0Desired * params.amount1Desired));
            amount0 = params.amount0Desired;
            amount1 = params.amount1Desired;
        } else {
            // Proportional deposit
            uint256 liquidity0 = FullMath.mulDiv(params.amount0Desired, state.liquidity, state.reserve0);
            uint256 liquidity1 = FullMath.mulDiv(params.amount1Desired, state.liquidity, state.reserve1);

            liquidity = uint128(liquidity0 < liquidity1 ? liquidity0 : liquidity1);

            amount0 = FullMath.mulDiv(uint256(liquidity), state.reserve0, state.liquidity);
            amount1 = FullMath.mulDiv(uint256(liquidity), state.reserve1, state.liquidity);
        }

        require(liquidity > 0, "LiquidityFacet: zero liquidity");
        require(amount0 >= params.amount0Min, "LiquidityFacet: amount0 below min");
        require(amount1 >= params.amount1Min, "LiquidityFacet: amount1 below min");

        // Transfer tokens in
        LibTransfer.pullToken(config.token0, msg.sender, amount0);
        LibTransfer.pullToken(config.token1, msg.sender, amount1);

        // Create position
        positionId = LibPosition.createPosition(
            params.poolId,
            params.recipient,
            params.tickLower,
            params.tickUpper,
            liquidity,
            state.feeGrowthGlobal0X128,
            state.feeGrowthGlobal1X128
        );

        // Update pool state
        state.liquidity += liquidity;
        state.reserve0 += amount0;
        state.reserve1 += amount1;

        // Update oracle
        LibOracle.write(params.poolId, state.currentTick, state.liquidity);

        emit LiquidityAdded(
            params.poolId,
            params.recipient,
            positionId,
            params.tickLower,
            params.tickUpper,
            liquidity,
            amount0,
            amount1
        );

        LibEventEmitter.emitLiquidityAdded(
            params.poolId,
            params.recipient,
            positionId,
            params.tickLower,
            params.tickUpper,
            liquidity,
            amount0,
            amount1,
            state.reserve0,
            state.reserve1,
            state.liquidity
        );

        LibSecurity.nonReentrantAfter();
    }

    /// @inheritdoc ILiquidityFacet
    function removeLiquidity(
        RemoveLiquidityParams calldata params
    ) external returns (uint256 amount0, uint256 amount1) {
        LibSecurity.nonReentrantBefore();
        LibSecurity.checkDeadline(params.deadline);

        AppStorage storage s = LibAppStorage.appStorage();
        ILiquidityFacet.Position storage pos = s.positions[params.positionId];
        IPool.PoolConfig storage config = s.poolConfigs[params.poolId];
        IPool.PoolState storage state = s.poolStates[params.poolId];

        require(pos.owner == msg.sender, "LiquidityFacet: not owner");
        require(pos.poolId == params.poolId, "LiquidityFacet: pool mismatch");
        require(params.liquidityAmount <= pos.liquidity, "LiquidityFacet: insufficient liquidity");

        // Calculate token amounts to return
        amount0 = FullMath.mulDiv(uint256(params.liquidityAmount), state.reserve0, state.liquidity);
        amount1 = FullMath.mulDiv(uint256(params.liquidityAmount), state.reserve1, state.liquidity);

        require(amount0 >= params.amount0Min, "LiquidityFacet: amount0 below min");
        require(amount1 >= params.amount1Min, "LiquidityFacet: amount1 below min");

        // Update fees before removing liquidity
        LibPosition.updateFees(params.positionId, state.feeGrowthGlobal0X128, state.feeGrowthGlobal1X128);

        // Remove liquidity from position
        LibPosition.removeLiquidity(params.positionId, params.liquidityAmount);

        // Update pool state
        state.liquidity -= params.liquidityAmount;
        state.reserve0 -= amount0;
        state.reserve1 -= amount1;

        // Transfer tokens out
        LibTransfer.pushToken(config.token0, params.recipient, amount0);
        LibTransfer.pushToken(config.token1, params.recipient, amount1);

        // Update oracle
        LibOracle.write(params.poolId, state.currentTick, state.liquidity);

        emit LiquidityRemoved(
            params.poolId,
            msg.sender,
            params.positionId,
            pos.tickLower,
            pos.tickUpper,
            params.liquidityAmount,
            amount0,
            amount1
        );

        LibEventEmitter.emitLiquidityRemoved(
            params.poolId,
            msg.sender,
            params.positionId,
            params.liquidityAmount,
            amount0,
            amount1,
            state.reserve0,
            state.reserve1,
            state.liquidity
        );

        LibSecurity.nonReentrantAfter();
    }

    /// @inheritdoc ILiquidityFacet
    function collectFees(
        bytes32 poolId,
        uint256 positionId,
        address recipient
    ) external returns (uint256 amount0, uint256 amount1) {
        LibSecurity.nonReentrantBefore();

        AppStorage storage s = LibAppStorage.appStorage();
        ILiquidityFacet.Position storage pos = s.positions[positionId];
        IPool.PoolConfig storage config = s.poolConfigs[poolId];
        IPool.PoolState storage state = s.poolStates[poolId];

        require(pos.owner == msg.sender, "LiquidityFacet: not owner");
        require(pos.poolId == poolId, "LiquidityFacet: pool mismatch");

        // Update and collect fees
        LibPosition.updateFees(positionId, state.feeGrowthGlobal0X128, state.feeGrowthGlobal1X128);
        (amount0, amount1) = LibPosition.collectFees(positionId);

        // Transfer fees out
        if (amount0 > 0) LibTransfer.pushToken(config.token0, recipient, amount0);
        if (amount1 > 0) LibTransfer.pushToken(config.token1, recipient, amount1);

        emit FeesCollected(poolId, msg.sender, positionId, amount0, amount1);

        LibSecurity.nonReentrantAfter();
    }

    /// @inheritdoc ILiquidityFacet
    function getPosition(uint256 positionId) external view returns (Position memory) {
        return LibPosition.getPosition(positionId);
    }
}
