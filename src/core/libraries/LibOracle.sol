// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../storage/AppStorage.sol";

/// @title LibOracle — Internal TWAP oracle with ring buffer observations
/// @notice Maintains price observations for time-weighted average price computation
/// @dev Custom implementation — no external dependencies
library LibOracle {
    error OracleNotInitialized();
    error InvalidObservationPeriod();
    error InsufficientObservationHistory();

    /// @notice Initialize the oracle for a pool with the first observation
    /// @param poolId The pool identifier
    /// @param tick The initial tick
    function initialize(bytes32 poolId, int24 tick) internal {
        AppStorage storage s = LibAppStorage.appStorage();

        s.observations[poolId][0] = Observation({
            blockTimestamp: uint32(block.timestamp),
            tickCumulative: 0,
            secondsPerLiquidityCumulativeX128: 0,
            initialized: true
        });

        s.oracleStates[poolId] = OracleState({
            index: 0,
            cardinality: 1,
            cardinalityNext: 1
        });
    }

    /// @notice Write a new observation to the ring buffer
    /// @param poolId The pool identifier
    /// @param tick The current tick
    /// @param liquidity The current liquidity
    /// @return indexUpdated The index of the newly written observation
    /// @return cardinalityUpdated The new cardinality
    function write(
        bytes32 poolId,
        int24 tick,
        uint128 liquidity
    ) internal returns (uint16 indexUpdated, uint16 cardinalityUpdated) {
        AppStorage storage s = LibAppStorage.appStorage();
        OracleState storage state = s.oracleStates[poolId];
        Observation storage last = s.observations[poolId][state.index];

        // Only write if the block timestamp has changed
        if (last.blockTimestamp == uint32(block.timestamp)) {
            return (state.index, state.cardinality);
        }

        uint32 delta = uint32(block.timestamp) - last.blockTimestamp;

        // Compute new cumulative values
        int56 newTickCumulative = last.tickCumulative + int56(tick) * int56(uint56(delta));
        uint160 newSecondsPerLiquidityCumulative = last.secondsPerLiquidityCumulativeX128 +
            ((uint160(delta) << 128) / (liquidity > 0 ? liquidity : 1));

        // Advance to next index
        indexUpdated = (state.index + 1) % state.cardinalityNext;
        cardinalityUpdated = indexUpdated >= state.cardinality ? indexUpdated + 1 : state.cardinality;

        s.observations[poolId][indexUpdated] = Observation({
            blockTimestamp: uint32(block.timestamp),
            tickCumulative: newTickCumulative,
            secondsPerLiquidityCumulativeX128: newSecondsPerLiquidityCumulative,
            initialized: true
        });

        state.index = indexUpdated;
        state.cardinality = cardinalityUpdated;
    }

    /// @notice Expand the oracle's observation buffer capacity
    /// @param poolId The pool identifier
    /// @param cardinalityNext The desired minimum cardinality
    function grow(bytes32 poolId, uint16 cardinalityNext) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        OracleState storage state = s.oracleStates[poolId];

        if (cardinalityNext <= state.cardinalityNext) return;
        state.cardinalityNext = cardinalityNext;
    }

    /// @notice Compute the TWAP tick over a given lookback period
    /// @param poolId The pool identifier
    /// @param period The lookback period in seconds
    /// @return arithmeticMeanTick The time-weighted average tick
    function consult(bytes32 poolId, uint32 period) internal view returns (int24 arithmeticMeanTick) {
        if (period == 0) revert InvalidObservationPeriod();

        AppStorage storage s = LibAppStorage.appStorage();
        OracleState storage state = s.oracleStates[poolId];

        if (state.cardinality == 0) revert OracleNotInitialized();

        Observation storage latest = s.observations[poolId][state.index];
        uint32 currentTime = uint32(block.timestamp);
        uint32 targetTime = currentTime - period;

        // Find the observation at or before targetTime
        (int56 tickCumulativeAtTarget, ) = _observeAt(
            s.observations[poolId],
            state.index,
            state.cardinality,
            targetTime
        );

        int56 tickCumulativeDelta = latest.tickCumulative +
            (int56(int24(_getCurrentTick(poolId))) * int56(uint56(currentTime - latest.blockTimestamp))) -
            tickCumulativeAtTarget;

        arithmeticMeanTick = int24(tickCumulativeDelta / int56(uint56(period)));

        // Always round to negative infinity
        if (tickCumulativeDelta < 0 && (tickCumulativeDelta % int56(uint56(period)) != 0)) {
            arithmeticMeanTick--;
        }
    }

    /// @notice Observe tick cumulatives at multiple seconds ago
    /// @param poolId The pool identifier
    /// @param secondsAgos Array of seconds ago values
    /// @return tickCumulatives The cumulative tick values at each requested time
    function observe(
        bytes32 poolId,
        uint32[] memory secondsAgos
    ) internal view returns (int56[] memory tickCumulatives) {
        AppStorage storage s = LibAppStorage.appStorage();
        OracleState storage state = s.oracleStates[poolId];

        tickCumulatives = new int56[](secondsAgos.length);

        for (uint256 i = 0; i < secondsAgos.length; i++) {
            uint32 targetTime = uint32(block.timestamp) - secondsAgos[i];
            (int56 tickCumulative, ) = _observeAt(
                s.observations[poolId],
                state.index,
                state.cardinality,
                targetTime
            );
            tickCumulatives[i] = tickCumulative;
        }
    }

    /// @dev Binary search for the observation at or before a given timestamp
    function _observeAt(
        Observation[65535] storage observations,
        uint16 index,
        uint16 cardinality,
        uint32 target
    ) private view returns (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) {
        Observation storage beforeOrAt = observations[0];
        Observation storage atOrAfter = observations[0];

        // Binary search for the closest observation
        uint256 l = (index + 1) % cardinality;
        uint256 r = l + cardinality - 1;

        while (l <= r) {
            uint256 mid = (l + r) / 2;
            beforeOrAt = observations[mid % cardinality];

            if (!beforeOrAt.initialized) {
                l = mid + 1;
                continue;
            }

            if (beforeOrAt.blockTimestamp <= target) {
                // Check the next observation
                atOrAfter = observations[(mid + 1) % cardinality];
                if (!atOrAfter.initialized || atOrAfter.blockTimestamp > target) {
                    // Interpolate between beforeOrAt and target
                    uint32 delta = target - beforeOrAt.blockTimestamp;
                    // Use last known tick for interpolation
                    return (
                        beforeOrAt.tickCumulative,
                        beforeOrAt.secondsPerLiquidityCumulativeX128
                    );
                }
                l = mid + 1;
            } else {
                r = mid - 1;
            }
        }

        return (beforeOrAt.tickCumulative, beforeOrAt.secondsPerLiquidityCumulativeX128);
    }

    /// @dev Get the current tick for a pool
    function _getCurrentTick(bytes32 poolId) private view returns (int24) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.poolStates[poolId].currentTick;
    }
}
