// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../interfaces/IFeeFacet.sol";
import "../libraries/LibFee.sol";
import "../libraries/LibSecurity.sol";
import "../libraries/LibTransfer.sol";
import "../storage/AppStorage.sol";

/// @title FeeFacet — Progressive fee configuration and protocol fee collection
/// @notice fee(x) = baseFee + impactFee * (x/L)^2
/// @dev Diamond facet — operates on AppStorage via delegatecall
contract FeeFacet is IFeeFacet {
    /// @inheritdoc IFeeFacet
    function calculateFee(bytes32 poolId, uint256 tradeSize) external view returns (uint256 feeBps) {
        AppStorage storage s = LibAppStorage.appStorage();
        IPool.PoolState storage state = s.poolStates[poolId];

        uint256 poolLiquidity = state.reserve0 + state.reserve1; // Simplified liquidity metric
        feeBps = LibFee.calculateProgressiveFee(
            s.feeConfigs[poolId].baseFee,
            s.feeConfigs[poolId].maxImpactFee,
            tradeSize,
            poolLiquidity
        );
    }

    /// @inheritdoc IFeeFacet
    function setFeeConfig(bytes32 poolId, FeeConfig calldata config) external {
        LibSecurity.requireOwner();
        LibFee.validateFeeConfig(config);

        AppStorage storage s = LibAppStorage.appStorage();
        s.feeConfigs[poolId] = config;

        emit FeeConfigUpdated(poolId, config.baseFee, config.maxImpactFee);
    }

    /// @inheritdoc IFeeFacet
    function collectProtocolFees(
        bytes32 poolId,
        address recipient
    ) external returns (uint256 amount0, uint256 amount1) {
        LibSecurity.requireOwner();

        AppStorage storage s = LibAppStorage.appStorage();
        IPool.PoolState storage state = s.poolStates[poolId];
        IPool.PoolConfig storage config = s.poolConfigs[poolId];

        amount0 = state.protocolFees0;
        amount1 = state.protocolFees1;

        if (amount0 > 0) {
            state.protocolFees0 = 0;
            LibTransfer.pushToken(config.token0, recipient, amount0);
        }

        if (amount1 > 0) {
            state.protocolFees1 = 0;
            LibTransfer.pushToken(config.token1, recipient, amount1);
        }

        emit ProtocolFeesCollected(poolId, amount0, amount1);
    }

    /// @inheritdoc IFeeFacet
    function getFeeConfig(bytes32 poolId) external view returns (FeeConfig memory) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.feeConfigs[poolId];
    }
}

import "../interfaces/IPool.sol";
