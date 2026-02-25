// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../interfaces/IOracleFacet.sol";
import "../libraries/LibOracle.sol";
import "../libraries/LibSecurity.sol";
import "../storage/AppStorage.sol";

/// @title OracleFacet — Internal TWAP oracle for all pools
/// @notice Provides time-weighted average price queries using a ring buffer of observations
/// @dev Diamond facet — operates on AppStorage via delegatecall
contract OracleFacet is IOracleFacet {
    /// @inheritdoc IOracleFacet
    function consultTWAP(bytes32 poolId, uint32 period) external view returns (int24 arithmeticMeanTick) {
        arithmeticMeanTick = LibOracle.consult(poolId, period);
    }

    /// @inheritdoc IOracleFacet
    function getSpotTick(bytes32 poolId) external view returns (int24 tick) {
        AppStorage storage s = LibAppStorage.appStorage();
        require(s.poolStates[poolId].initialized, "OracleFacet: pool not initialized");
        tick = s.poolStates[poolId].currentTick;
    }

    /// @inheritdoc IOracleFacet
    function observe(
        bytes32 poolId,
        uint32[] calldata secondsAgos
    ) external view returns (int56[] memory tickCumulatives) {
        tickCumulatives = LibOracle.observe(poolId, secondsAgos);
    }

    /// @inheritdoc IOracleFacet
    function increaseObservationCardinalityNext(bytes32 poolId, uint16 observationCardinalityNext) external {
        LibOracle.grow(poolId, observationCardinalityNext);
    }

    /// @notice Get oracle state for a pool
    function getOracleState(
        bytes32 poolId
    ) external view returns (uint16 index, uint16 cardinality, uint16 cardinalityNext) {
        AppStorage storage s = LibAppStorage.appStorage();
        OracleState storage state = s.oracleStates[poolId];
        index = state.index;
        cardinality = state.cardinality;
        cardinalityNext = state.cardinalityNext;
    }
}
