// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../../utils/FullMath.sol";
import "../storage/AppStorage.sol";
import "../interfaces/IFeeFacet.sol";

/// @title LibFee — Progressive quadratic fee calculation
/// @notice fee(x) = baseFee + impactFee * (x/L)²
/// @dev Custom implementation — no external dependencies
library LibFee {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant BPS_SQUARED = 100_000_000; // BPS * BPS for precision
    uint256 internal constant MAX_FEE_BPS = 5000; // 50% absolute max fee cap

    error FeeExceedsMaximum();
    error InvalidFeeConfig();

    /// @notice Calculate the progressive fee for a trade
    /// @param baseFee The base fee in basis points
    /// @param maxImpactFee The maximum impact fee in basis points
    /// @param tradeSize The absolute trade size
    /// @param poolLiquidity The total pool liquidity in the traded token
    /// @return feeBps The total fee in basis points
    function calculateProgressiveFee(
        uint256 baseFee,
        uint256 maxImpactFee,
        uint256 tradeSize,
        uint256 poolLiquidity
    ) internal pure returns (uint256 feeBps) {
        if (poolLiquidity == 0) return baseFee;

        // Compute (tradeSize / poolLiquidity)² in basis points
        // ratio = tradeSize * BPS / poolLiquidity
        uint256 ratio = FullMath.mulDiv(tradeSize, BPS, poolLiquidity);

        // impactComponent = maxImpactFee * ratio² / BPS²
        uint256 ratioSquared = ratio * ratio;
        uint256 impactComponent = FullMath.mulDiv(maxImpactFee, ratioSquared, BPS_SQUARED);

        feeBps = baseFee + impactComponent;

        // Cap at maximum
        if (feeBps > MAX_FEE_BPS) {
            feeBps = MAX_FEE_BPS;
        }
    }

    /// @notice Apply fee to an amount and return (amountAfterFee, feeAmount)
    /// @param amount The gross amount
    /// @param feeBps The fee in basis points
    /// @return netAmount The amount after fee deduction
    /// @return feeAmount The fee amount
    function applyFee(uint256 amount, uint256 feeBps) internal pure returns (uint256 netAmount, uint256 feeAmount) {
        feeAmount = FullMath.mulDiv(amount, feeBps, BPS);
        netAmount = amount - feeAmount;
    }

    /// @notice Distribute collected fees between LP, protocol, and trader pool
    /// @param totalFee The total fee amount
    /// @param lpShareBps LP share in basis points (e.g., 7000 = 70%)
    /// @param protocolShareBps Protocol share in basis points
    /// @param traderShareBps Trader rebate share in basis points
    /// @return lpFee The LP portion
    /// @return protocolFee The protocol portion
    /// @return traderFee The trader rebate portion
    function distributeFee(
        uint256 totalFee,
        uint256 lpShareBps,
        uint256 protocolShareBps,
        uint256 traderShareBps
    ) internal pure returns (uint256 lpFee, uint256 protocolFee, uint256 traderFee) {
        lpFee = FullMath.mulDiv(totalFee, lpShareBps, BPS);
        protocolFee = FullMath.mulDiv(totalFee, protocolShareBps, BPS);
        // Trader pool gets the remainder to avoid rounding losses
        traderFee = totalFee - lpFee - protocolFee;
    }

    /// @notice Validate a fee configuration
    function validateFeeConfig(IFeeFacet.FeeConfig memory config) internal pure {
        if (config.baseFee > BPS) revert InvalidFeeConfig();
        if (config.maxImpactFee > MAX_FEE_BPS) revert InvalidFeeConfig();
        if (config.lpShareBps + config.protocolShareBps + config.traderShareBps != BPS) {
            revert InvalidFeeConfig();
        }
    }

    /// @notice Get the default fee configuration
    /// @return config The default fee config
    function defaultFeeConfig() internal pure returns (IFeeFacet.FeeConfig memory config) {
        config = IFeeFacet.FeeConfig({
            baseFee: 1, // 0.01%
            maxImpactFee: 1000, // 10% max impact fee
            lpShareBps: 7000, // 70%
            protocolShareBps: 2000, // 20%
            traderShareBps: 1000 // 10%
        });
    }
}
