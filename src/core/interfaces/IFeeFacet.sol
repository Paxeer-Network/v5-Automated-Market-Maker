// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title IFeeFacet — Interface for progressive fee calculation and distribution
/// @notice fee(x) = baseFee + impactFee * (x/L)^2
interface IFeeFacet {
    struct FeeConfig {
        uint256 baseFee;         // Base fee in basis points (1 = 0.01%)
        uint256 maxImpactFee;    // Maximum impact fee in basis points
        uint256 lpShareBps;      // LP share in basis points (7000 = 70%)
        uint256 protocolShareBps; // Protocol share in basis points (2000 = 20%)
        uint256 traderShareBps;  // Trader rebate pool share (1000 = 10%)
    }

    event FeeConfigUpdated(bytes32 indexed poolId, uint256 baseFee, uint256 maxImpactFee);
    event ProtocolFeesCollected(bytes32 indexed poolId, uint256 amount0, uint256 amount1);

    /// @notice Calculate the progressive fee for a given trade size
    /// @param poolId The pool identifier
    /// @param tradeSize The absolute trade size in token units
    /// @return feeBps The total fee in basis points
    function calculateFee(bytes32 poolId, uint256 tradeSize) external view returns (uint256 feeBps);

    /// @notice Update fee configuration for a pool (owner only)
    function setFeeConfig(bytes32 poolId, FeeConfig calldata config) external;

    /// @notice Collect accumulated protocol fees
    function collectProtocolFees(bytes32 poolId, address recipient) external returns (uint256 amount0, uint256 amount1);

    /// @notice Get current fee config for a pool
    function getFeeConfig(bytes32 poolId) external view returns (FeeConfig memory);
}
