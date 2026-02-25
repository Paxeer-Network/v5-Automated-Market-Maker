// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title IOracleFacet — Interface for the internal TWAP oracle
/// @notice Maintains a ring buffer of price observations for TWAP computation
interface IOracleFacet {
    struct Observation {
        uint32 blockTimestamp;
        int56 tickCumulative;
        uint160 secondsPerLiquidityCumulativeX128;
        bool initialized;
    }

    event ObservationRecorded(bytes32 indexed poolId, uint32 timestamp, int24 tick, uint128 liquidity);

    /// @notice Get the TWAP tick over a given period
    /// @param poolId The pool identifier
    /// @param period The lookback period in seconds
    /// @return arithmeticMeanTick The time-weighted average tick
    function consultTWAP(bytes32 poolId, uint32 period) external view returns (int24 arithmeticMeanTick);

    /// @notice Get the current spot tick
    /// @param poolId The pool identifier
    /// @return tick The current tick
    function getSpotTick(bytes32 poolId) external view returns (int24 tick);

    /// @notice Get multiple observations
    /// @param poolId The pool identifier
    /// @param secondsAgos Array of seconds ago to query
    /// @return tickCumulatives The tick cumulative values at each point
    function observe(bytes32 poolId, uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives);

    /// @notice Expand the observation buffer capacity
    function increaseObservationCardinalityNext(bytes32 poolId, uint16 observationCardinalityNext) external;
}
