// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title FullMath — 512-bit multiplication and division
/// @notice Handles overflow-safe mulDiv operations for fixed-point arithmetic
/// @dev Adapted from Remco Bloemen's technique (https://2π.com)
///      Custom implementation — no external dependencies
library FullMath {
    /// @notice Calculates floor(a * b / denominator) with full 512-bit precision
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        // 512-bit multiply [prod1 prod0] = a * b
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // Handle non-overflow cases, 256 by 256 division
        if (prod1 == 0) {
            require(denominator > 0, "FullMath: division by zero");
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        // Make sure the result is less than 2^256
        require(denominator > prod1, "FullMath: denominator <= prod1");

        ///////////////////////////////////////////////
        // 512 by 256 division
        ///////////////////////////////////////////////

        // Make division exact by subtracting the remainder from [prod1 prod0]
        uint256 remainder;
        assembly {
            remainder := mulmod(a, b, denominator)
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        // Factor powers of two out of denominator
        // Compute largest power of two divisor of denominator
        // Always >= 1
        uint256 twos = denominator & (0 - denominator);
        assembly {
            // Divide denominator by power of two
            denominator := div(denominator, twos)
            // Divide [prod1 prod0] by the factors of two
            prod0 := div(prod0, twos)
            // Shift in bits from prod1 into prod0
            // For this we need to flip `twos` such that it is 2^256 / twos
            // If twos is zero, then it becomes one
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        // Invert denominator mod 2^256
        // Now that denominator is an odd number, it has an inverse
        // modulo 2^256 such that denominator * inv = 1 mod 2^256
        // Compute the inverse by starting with a seed that is correct
        // for four bits. That is, denominator * inv = 1 mod 2^4
        uint256 inv = (3 * denominator) ^ 2;

        // Now use Newton-Raphson iteration to improve the precision
        // Thanks to Hensel's lifting lemma, this also works in modular
        // arithmetic, doubling the correct bits in each step
        inv *= 2 - denominator * inv; // inverse mod 2^8
        inv *= 2 - denominator * inv; // inverse mod 2^16
        inv *= 2 - denominator * inv; // inverse mod 2^32
        inv *= 2 - denominator * inv; // inverse mod 2^64
        inv *= 2 - denominator * inv; // inverse mod 2^128
        inv *= 2 - denominator * inv; // inverse mod 2^256

        // Because the division is now exact we can divide by multiplying
        // with the modular inverse of denominator. This will give us the
        // correct result modulo 2^256. Since the preconditions guarantee
        // that the outcome is less than 2^256, this is the final result.
        // We don't need to compute the high bits of the result and prod1
        // is no longer required.
        result = prod0 * inv;
    }

    /// @notice Calculates ceil(a * b / denominator) with full 512-bit precision
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max, "FullMath: result overflow");
            result++;
        }
    }

    /// @notice Calculates a * b >> 128 using full 512-bit precision
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @return The result shifted right by 128 bits
    function mulDivQ128(uint256 a, uint256 b) internal pure returns (uint256) {
        return mulDiv(a, b, 1 << 128);
    }
}
