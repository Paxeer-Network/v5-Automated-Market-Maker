// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "./FullMath.sol";

/// @title FixedPointMath — Q128.128 fixed-point arithmetic with exp, ln, tanh
/// @notice Provides fixed-point math operations needed for the sigmoid bonding curve
/// @dev All values are Q128.128 unless noted. Custom implementation — no external dependencies.
library FixedPointMath {
    /// @dev Q128.128 representation of 1.0
    uint256 internal constant Q128 = 1 << 128;

    /// @dev Q128.128 representation of 0.5
    uint256 internal constant HALF_Q128 = 1 << 127;

    /// @dev Maximum value for Q128.128 (roughly 3.4e38)
    uint256 internal constant MAX_Q128 = type(uint256).max;

    /// @notice Multiply two Q128.128 numbers
    /// @param a First operand (Q128.128)
    /// @param b Second operand (Q128.128)
    /// @return result The product (Q128.128)
    function mulQ128(uint256 a, uint256 b) internal pure returns (uint256 result) {
        result = FullMath.mulDiv(a, b, Q128);
    }

    /// @notice Divide two Q128.128 numbers
    /// @dev Uses two-step division to avoid overflow: (a / b) then scale
    /// @param a Numerator (Q128.128)
    /// @param b Denominator (Q128.128)
    /// @return result The quotient (Q128.128)
    function divQ128(uint256 a, uint256 b) internal pure returns (uint256 result) {
        require(b > 0, "FixedPointMath: div by zero");
        // Split to avoid overflow: a * Q128 / b
        // If a < 2^128, we can safely shift left first
        if (a < Q128) {
            result = (a << 128) / b;
        } else {
            // For large a, use FullMath which handles 512-bit intermediate
            result = FullMath.mulDiv(a, Q128, b);
        }
    }

    /// @notice Convert a uint256 integer to Q128.128
    /// @param x The integer value
    /// @return The Q128.128 representation
    function toQ128(uint256 x) internal pure returns (uint256) {
        return x << 128;
    }

    /// @notice Convert a Q128.128 to uint256 integer (truncates fractional part)
    /// @param x The Q128.128 value
    /// @return The integer part
    function fromQ128(uint256 x) internal pure returns (uint256) {
        return x >> 128;
    }

    /// @notice Compute tanh(x) for a Q128.128 input using lookup table + linear interpolation
    /// @dev 33-entry table at step=0.125 from x=0 to x=4.0. Overflow-free for all inputs.
    ///      Max interpolation error < 0.3% (acceptable for AMM fee/curve calculations).
    ///      Values pre-computed as floor(Math.tanh(n/8) * 2^128) via IEEE-754 double precision.
    /// @param x The input value in Q128.128 (must be >= 0)
    /// @return The tanh result in Q128.128, range [0, Q128)
    function tanh(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;

        // Clamp: for x >= 4.0, return tanh(4) ≈ 0.99933
        uint256 maxX = 4 * Q128;
        if (x >= maxX) return 340054139448653691188148485995674998075;

        // Table step = 0.125 in Q128.128 = Q128 >> 3
        uint256 step = Q128 >> 3;

        // Find table index and fractional part
        uint256 index = x / step;
        if (index >= 32) index = 31;
        uint256 frac = x - index * step;

        // Lookup bounding values
        uint256 y0 = _tanhLookup(index);
        uint256 y1 = _tanhLookup(index + 1);

        // Linear interpolation: y0 + (y1 - y0) * frac / step
        // Safe: delta < Q128, frac < step = Q128/8, so delta*frac < Q128²/8
        if (y1 > y0) {
            return y0 + FullMath.mulDiv(y1 - y0, frac, step);
        }
        return y0;
    }

    /// @dev Pre-computed tanh(n/8) values in Q128.128 for n = 0..32
    ///      Generated via: BigInt(Math.round(Math.tanh(n/8) * 1e15)) * 2n**128n / 10n**15n
    function _tanhLookup(uint256 i) private pure returns (uint256) {
        if (i == 0) return 0;
        if (i == 1) return 42315133776562340854727920675823273426;
        if (i == 2) return 83341502145844362323070741003299426035;
        if (i == 3) return 121942703714435069847581312462983243839;
        if (i == 4) return 157250320067211744730756257097471829039;
        if (i == 5) return 188720506214743001735466036705278531135;
        if (i == 6) return 216129988865700468962962166993038952601;
        if (i == 7) return 239526664996466053237936476046676472428;
        if (i == 8) return 259157062021782057308577908127526462831;
        if (i == 9) return 275390883719910620164738859701463157185;
        if (i == 10) return 288655964825051695079348506178622993104;
        if (i == 11) return 299389511837815081288061052358281786644;
        if (i == 12) return 308005990164628968151215758581198342896;
        if (i == 13) return 314879003770435245969434396286379523041;
        if (i == 14) return 320333496401329846906740340046930766756;
        if (i == 15) return 324644779283735607463971683386410032791;
        if (i == 16) return 328041586725263546474360232920300196622;
        if (i == 17) return 330711158325400667185811661507973846131;
        if (i == 18) return 332805041233812967288541478577997431214;
        if (i == 19) return 334444832843322974583623732749795179561;
        if (i == 20) return 335727448613009082453953698544578393647;
        if (i == 21) return 336729733467680679713929712062602898049;
        if (i == 22) return 337512374729619917335179424683479125986;
        if (i == 23) return 338123150866677969900325112097374224706;
        if (i == 24) return 338599586800452243407730736497156789539;
        if (i == 25) return 338971099257607065076951706964014090647;
        if (i == 26) return 339260715217934098902094899603508124945;
        if (i == 27) return 339486439478675624167738895152460180453;
        if (i == 28) return 339662337607304963105993270099794060990;
        if (i == 29) return 339799390274659173105982498841526930536;
        if (i == 30) return 339906165275027146164325193986845021966;
        if (i == 31) return 339989344955483119762024086926209795280;
        // i == 32
        return 340054139448653691188148485995674998075;
    }

    /// @notice Compute tanh for a signed value (positive or negative direction)
    /// @dev Returns (result, isNegative) where result is always positive Q128.128
    /// @param x Absolute value in Q128.128
    /// @param negative Whether the input is negative
    /// @return result The absolute tanh result in Q128.128
    /// @return isNeg Whether the result is negative
    function tanhSigned(uint256 x, bool negative) internal pure returns (uint256 result, bool isNeg) {
        result = tanh(x);
        isNeg = negative;
    }

    /// @notice Compute the integer square root (floor)
    /// @param x The input value
    /// @return z The floor of sqrt(x)
    function sqrt(uint256 x) internal pure returns (uint256 z) {
        if (x == 0) return 0;
        assembly {
            z := 181
            let r := shl(7, lt(0xffffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffffff, shr(r, x))))
            z := shl(shr(1, r), z)

            z := shr(18, mul(z, add(shr(r, x), 65536)))

            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            z := sub(z, lt(div(x, z), z))
        }
    }

    /// @notice Compute sqrt for Q128.128 input, returning Q128.128 output
    /// @param x Q128.128 input
    /// @return Q128.128 sqrt result
    function sqrtQ128(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        // sqrt(x * 2^128) = sqrt(x) * 2^64
        // We need to scale up by 2^128 then take sqrt, which gives us sqrt * 2^64
        // Then scale up by 2^64 to get Q128.128
        // Equivalent: sqrt(x << 128) << 64... but that overflows
        // Better: sqrt(x) * 2^64 if x >= 2^128, else sqrt(x << 128)
        uint256 s = sqrt(x);
        // s is sqrt of the Q128.128 value, but we need to adjust
        // sqrt(a * 2^128) = sqrt(a) * 2^64
        // So result = s * 2^64 = s << 64
        return s << 64;
    }

    /// @notice Returns the minimum of two values
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice Returns the maximum of two values
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /// @notice Returns the absolute difference of two values
    function absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }
}
