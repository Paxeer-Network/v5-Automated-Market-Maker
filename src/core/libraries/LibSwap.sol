// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../../utils/FixedPointMath.sol";
import "../../utils/FullMath.sol";
import "../../utils/SqrtPriceMath.sol";
import "../storage/AppStorage.sol";
import "./LibPool.sol";
import "./LibFee.sol";

/// @title LibSwap — Sigmoid bonding curve swap math
/// @notice Computes swap outputs using the ASAMM tanh-based price impact model
/// @dev P(x) = P_mid * (1 + k * tanh(α * x / L))
///      Custom implementation — no external dependencies
library LibSwap {
    using FixedPointMath for uint256;

    error InsufficientInputAmount();
    error InsufficientOutputAmount();
    error InsufficientLiquidity();
    error PriceLimitReached();
    error DeadlineExpired();
    error ZeroAmount();

    uint256 internal constant Q128 = 1 << 128;
    uint256 internal constant BPS = 10000;

    struct SwapState {
        int256 amountSpecifiedRemaining;
        int256 amountCalculated;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
        uint256 feeGrowthGlobalX128;
        uint256 totalFees;
    }

    struct StepComputations {
        uint160 sqrtPriceStartX96;
        int24 tickNext;
        bool initialized;
        uint160 sqrtPriceNextX96;
        uint256 amountIn;
        uint256 amountOut;
        uint256 feeAmount;
    }

    /// @notice Compute the sigmoid-adjusted output amount for a swap
    /// @dev Uses the tanh approximation from FixedPointMath
    /// @param amountIn The input amount (before fees)
    /// @param reserveIn The input token reserve
    /// @param reserveOut The output token reserve
    /// @param alpha The sigmoid steepness parameter (Q128.128)
    /// @param k The max deviation factor (Q128.128)
    /// @return amountOut The output amount
    function computeSigmoidSwapOutput(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 alpha,
        uint256 k
    ) internal pure returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        // Compute x/L ratio in Q128.128
        // x = amountIn, L = reserveIn (liquidity in the input token)
        uint256 xOverL = FullMath.mulDiv(amountIn, Q128, reserveIn);

        // Compute α * x/L in Q128.128
        uint256 alphaXOverL = FixedPointMath.mulQ128(alpha, xOverL);

        // Compute tanh(α * x/L) — result in Q128.128
        uint256 tanhResult = FixedPointMath.tanh(alphaXOverL);

        // Price impact factor = k * tanh(α * x/L) in Q128.128
        uint256 impactFactor = FixedPointMath.mulQ128(k, tanhResult);

        // Effective exchange rate adjustment:
        // For a buy (zeroForOne), the price moves up → output decreases
        // output = reserveOut * amountIn / (reserveIn + amountIn) * (1 - impactFactor)
        // This is the constant-product baseline adjusted by the sigmoid

        // Step 1: Constant-product baseline output
        uint256 baseOutput = FullMath.mulDiv(reserveOut, amountIn, reserveIn + amountIn);

        // Step 2: Apply sigmoid reduction
        // effectiveOutput = baseOutput * (Q128 - impactFactor) / Q128
        // The impact factor reduces output for larger trades
        if (impactFactor >= Q128) {
            // Impact saturated — near-zero output (extreme whale trade)
            amountOut = baseOutput / 100; // 1% of base as minimum
        } else {
            uint256 reductionFactor = Q128 - impactFactor;
            amountOut = FullMath.mulDiv(baseOutput, reductionFactor, Q128);
        }

        if (amountOut == 0) revert InsufficientOutputAmount();
    }

    /// @notice Compute the output amount for an oracle-pegged pool
    /// @dev Uses the oracle mid-price as anchor instead of reserve ratio
    /// @param amountIn The input amount
    /// @param oracleMidPrice The oracle-derived mid-price (Q128.128)
    /// @param liquidity The pool's total liquidity
    /// @param alpha The sigmoid steepness parameter (Q128.128)
    /// @param k The max deviation factor (Q128.128)
    /// @param zeroForOne The swap direction
    /// @return amountOut The output amount
    function computePeggedSwapOutput(
        uint256 amountIn,
        uint256 oracleMidPrice,
        uint128 liquidity,
        uint256 alpha,
        uint256 k,
        bool zeroForOne
    ) internal pure returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (liquidity == 0) revert InsufficientLiquidity();

        // Compute trade size relative to liquidity
        uint256 xOverL = FullMath.mulDiv(amountIn, Q128, uint256(liquidity));
        uint256 alphaXOverL = FixedPointMath.mulQ128(alpha, xOverL);
        uint256 tanhResult = FixedPointMath.tanh(alphaXOverL);
        uint256 impactFactor = FixedPointMath.mulQ128(k, tanhResult);

        // Base output at oracle price
        uint256 baseOutput;
        if (zeroForOne) {
            // Selling token0 for token1: output = amountIn * midPrice
            baseOutput = FullMath.mulDiv(amountIn, oracleMidPrice, Q128);
        } else {
            // Selling token1 for token0: output = amountIn / midPrice
            baseOutput = FullMath.mulDiv(amountIn, Q128, oracleMidPrice);
        }

        // Apply sigmoid reduction
        if (impactFactor >= Q128) {
            amountOut = baseOutput / 100;
        } else {
            uint256 reductionFactor = Q128 - impactFactor;
            amountOut = FullMath.mulDiv(baseOutput, reductionFactor, Q128);
        }

        if (amountOut == 0) revert InsufficientOutputAmount();
    }

    /// @notice Compute the required input amount for a desired output (exact output swap)
    /// @param amountOut The desired output amount
    /// @param reserveIn The input token reserve
    /// @param reserveOut The output token reserve
    /// @param alpha Sigmoid steepness (Q128.128)
    /// @param k Max deviation factor (Q128.128)
    /// @return amountIn The required input amount
    function computeSigmoidSwapInput(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 alpha,
        uint256 k
    ) internal pure returns (uint256 amountIn) {
        if (amountOut == 0) revert ZeroAmount();
        if (amountOut >= reserveOut) revert InsufficientLiquidity();

        // Inverse of the sigmoid output function
        // Start with constant-product inverse as initial estimate
        uint256 baseInput = FullMath.mulDiv(reserveIn, amountOut, reserveOut - amountOut) + 1;

        // The sigmoid makes output smaller, so we need MORE input
        // Estimate: amountIn = baseInput / (1 - k * tanh(α * baseInput/reserveIn))
        uint256 xOverL = FullMath.mulDiv(baseInput, Q128, reserveIn);
        uint256 alphaXOverL = FixedPointMath.mulQ128(alpha, xOverL);
        uint256 tanhResult = FixedPointMath.tanh(alphaXOverL);
        uint256 impactFactor = FixedPointMath.mulQ128(k, tanhResult);

        if (impactFactor >= Q128 - (Q128 / 100)) {
            // Near-saturation: use very large multiplier
            amountIn = baseInput * 100;
        } else {
            uint256 adjustmentFactor = Q128 - impactFactor;
            amountIn = FullMath.mulDiv(baseInput, Q128, adjustmentFactor) + 1;
        }
    }
}
