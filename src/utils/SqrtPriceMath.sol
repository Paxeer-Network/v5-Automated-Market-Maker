// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "./FullMath.sol";
import "./FixedPointMath.sol";

/// @title SqrtPriceMath — Conversions between sqrt price, liquidity, and token amounts
/// @notice Computes swap amounts and next prices given liquidity and price bounds
/// @dev Custom implementation — no external dependencies
library SqrtPriceMath {
    /// @dev Q96 constant (2^96) used in sqrtPriceX96 format
    uint256 internal constant Q96 = 0x1000000000000000000000000;

    /// @notice Gets the amount of token0 delta between two sqrt prices given liquidity
    /// @param sqrtPriceAX96 Lower sqrt price (Q64.96)
    /// @param sqrtPriceBX96 Upper sqrt price (Q64.96)
    /// @param liquidity The available liquidity
    /// @param roundUp Whether to round the result up
    /// @return amount0 The amount of token0 required
    function getAmount0Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount0) {
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }

        require(sqrtPriceAX96 > 0, "SqrtPriceMath: sqrtPrice cannot be zero");

        uint256 numerator1 = uint256(liquidity) << 96;
        uint256 numerator2 = sqrtPriceBX96 - sqrtPriceAX96;

        if (roundUp) {
            amount0 = _divRoundingUp(
                FullMath.mulDivRoundingUp(numerator1, numerator2, sqrtPriceBX96),
                sqrtPriceAX96
            );
        } else {
            amount0 = FullMath.mulDiv(numerator1, numerator2, sqrtPriceBX96) / sqrtPriceAX96;
        }
    }

    /// @notice Gets the amount of token1 delta between two sqrt prices given liquidity
    /// @param sqrtPriceAX96 Lower sqrt price (Q64.96)
    /// @param sqrtPriceBX96 Upper sqrt price (Q64.96)
    /// @param liquidity The available liquidity
    /// @param roundUp Whether to round the result up
    /// @return amount1 The amount of token1 required
    function getAmount1Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount1) {
        if (sqrtPriceAX96 > sqrtPriceBX96) {
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
        }

        if (roundUp) {
            amount1 = FullMath.mulDivRoundingUp(liquidity, sqrtPriceBX96 - sqrtPriceAX96, Q96);
        } else {
            amount1 = FullMath.mulDiv(liquidity, sqrtPriceBX96 - sqrtPriceAX96, Q96);
        }
    }

    /// @notice Computes the next sqrt price given an input amount of token0 or token1
    /// @param sqrtPriceX96 The current sqrt price (Q64.96)
    /// @param liquidity The pool liquidity
    /// @param amountIn The input amount
    /// @param zeroForOne Whether the swap is token0→token1
    /// @return sqrtPriceNextX96 The resulting sqrt price
    function getNextSqrtPriceFromInput(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtPriceNextX96) {
        require(sqrtPriceX96 > 0, "SqrtPriceMath: price zero");
        require(liquidity > 0, "SqrtPriceMath: liquidity zero");

        if (zeroForOne) {
            sqrtPriceNextX96 = _getNextSqrtPriceFromAmount0RoundingUp(sqrtPriceX96, liquidity, amountIn, true);
        } else {
            sqrtPriceNextX96 = _getNextSqrtPriceFromAmount1RoundingDown(sqrtPriceX96, liquidity, amountIn, true);
        }
    }

    /// @notice Computes the next sqrt price given an output amount of token0 or token1
    /// @param sqrtPriceX96 The current sqrt price (Q64.96)
    /// @param liquidity The pool liquidity
    /// @param amountOut The output amount
    /// @param zeroForOne Whether the swap is token0→token1
    /// @return sqrtPriceNextX96 The resulting sqrt price
    function getNextSqrtPriceFromOutput(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountOut,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtPriceNextX96) {
        require(sqrtPriceX96 > 0, "SqrtPriceMath: price zero");
        require(liquidity > 0, "SqrtPriceMath: liquidity zero");

        if (zeroForOne) {
            sqrtPriceNextX96 = _getNextSqrtPriceFromAmount1RoundingDown(sqrtPriceX96, liquidity, amountOut, false);
        } else {
            sqrtPriceNextX96 = _getNextSqrtPriceFromAmount0RoundingUp(sqrtPriceX96, liquidity, amountOut, false);
        }
    }

    /// @dev Gets next sqrt price from token0 amount, rounding up
    function _getNextSqrtPriceFromAmount0RoundingUp(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) private pure returns (uint160) {
        if (amount == 0) return sqrtPriceX96;

        uint256 numerator1 = uint256(liquidity) << 96;

        if (add) {
            uint256 product = amount * sqrtPriceX96;
            if (product / amount == sqrtPriceX96) {
                uint256 denominator = numerator1 + product;
                if (denominator >= numerator1) {
                    // Only use mulDivRoundingUp if numerator1 * sqrtPriceX96 won't overflow
                    // the 512-bit division (i.e., denominator > prod1 of the 512-bit product).
                    // Safe check: if numerator1 fits such that the product's high word < denominator.
                    if (numerator1 <= type(uint256).max / sqrtPriceX96) {
                        return uint160(FullMath.mulDivRoundingUp(numerator1, sqrtPriceX96, denominator));
                    }
                }
            }
            return uint160(_divRoundingUp(numerator1, (numerator1 / sqrtPriceX96) + amount));
        } else {
            uint256 product = amount * sqrtPriceX96;
            require(product / amount == sqrtPriceX96, "SqrtPriceMath: overflow");
            require(numerator1 > product, "SqrtPriceMath: underflow");
            uint256 denominator = numerator1 - product;
            return uint160(FullMath.mulDivRoundingUp(numerator1, sqrtPriceX96, denominator));
        }
    }

    /// @dev Gets next sqrt price from token1 amount, rounding down
    function _getNextSqrtPriceFromAmount1RoundingDown(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) private pure returns (uint160) {
        if (add) {
            uint256 quotient = (amount <= type(uint160).max)
                ? (amount << 96) / liquidity
                : FullMath.mulDiv(amount, Q96, liquidity);
            return uint160(uint256(sqrtPriceX96) + quotient);
        } else {
            uint256 quotient = (amount <= type(uint160).max)
                ? _divRoundingUp(amount << 96, liquidity)
                : FullMath.mulDivRoundingUp(amount, Q96, liquidity);
            require(sqrtPriceX96 > quotient, "SqrtPriceMath: price underflow");
            return uint160(uint256(sqrtPriceX96) - quotient);
        }
    }

    /// @dev Division rounding up helper
    function _divRoundingUp(uint256 a, uint256 b) private pure returns (uint256 result) {
        assembly {
            result := add(div(a, b), gt(mod(a, b), 0))
        }
    }
}
