// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title IOraclePegFacet — Interface for oracle-pegged pool management
/// @notice Connects external oracle feeds to pegged pools for wrapped assets
interface IOraclePegFacet {
    struct PegConfig {
        address oracleAddress; // IASAMMOracle implementation
        uint32 twapPeriod; // TWAP lookback period in seconds
        uint32 maxStaleness; // Max seconds before oracle is considered stale
        uint256 maxSpotDeviation; // Max % deviation between spot and TWAP (basis points)
    }

    event OraclePegSet(bytes32 indexed poolId, address indexed oracle, uint32 twapPeriod, uint32 maxStaleness);
    event OraclePegRemoved(bytes32 indexed poolId);
    event CircuitBreakerTriggered(bytes32 indexed poolId, string reason);

    /// @notice Set the oracle peg configuration for a pool
    function setOraclePeg(bytes32 poolId, PegConfig calldata config) external;

    /// @notice Remove the oracle peg from a pool (reverts to standard)
    function removeOraclePeg(bytes32 poolId) external;

    /// @notice Get the oracle-derived mid-price for a pegged pool
    /// @param poolId The pool identifier
    /// @return midPrice The oracle mid-price (Q128.128)
    /// @return isValid Whether the oracle data is fresh and consistent
    function getOracleMidPrice(bytes32 poolId) external view returns (uint256 midPrice, bool isValid);

    /// @notice Get the peg configuration for a pool
    function getPegConfig(bytes32 poolId) external view returns (PegConfig memory);
}
