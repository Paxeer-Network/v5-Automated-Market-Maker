// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../src/utils/FixedPointMath.sol";
import "./helpers/FixedPointMathWrapper.sol";

contract FixedPointMathFuzzTest is Test {
    uint256 internal constant Q128 = 1 << 128;
    FixedPointMathWrapper internal w;

    function setUp() public {
        w = new FixedPointMathWrapper();
    }

    // ─── toQ128 / fromQ128 round-trip ───

    /// @dev fromQ128(toQ128(x)) == x for values that don't overflow the shift
    function testFuzz_toFromQ128_roundTrip(uint128 x) public pure {
        uint256 q = FixedPointMath.toQ128(uint256(x));
        uint256 back = FixedPointMath.fromQ128(q);
        assertEq(back, uint256(x));
    }

    /// @dev fromQ128 truncates fractional part
    function testFuzz_fromQ128_truncates(uint256 x) public pure {
        uint256 result = FixedPointMath.fromQ128(x);
        assertEq(result, x >> 128);
    }

    // ─── mulQ128 ───

    /// @dev mulQ128(Q128, x) == x (multiplying by 1.0 in Q128.128)
    function testFuzz_mulQ128_identity(uint128 x) public pure {
        // Q128 represents 1.0; mulQ128(1.0, x) should return x
        uint256 result = FixedPointMath.mulQ128(Q128, uint256(x));
        assertEq(result, uint256(x));
    }

    /// @dev mulQ128(0, x) == 0
    function testFuzz_mulQ128_zero(uint256 x) public pure {
        assertEq(FixedPointMath.mulQ128(0, x), 0);
    }

    /// @dev mulQ128 is commutative
    function testFuzz_mulQ128_commutative(uint128 a, uint128 b) public pure {
        assertEq(FixedPointMath.mulQ128(uint256(a), uint256(b)), FixedPointMath.mulQ128(uint256(b), uint256(a)));
    }

    // ─── divQ128 ───

    /// @dev divQ128(x, Q128) == x (dividing by 1.0)
    function testFuzz_divQ128_byOne(uint64 x) public pure {
        uint256 xQ = uint256(x);
        uint256 result = FixedPointMath.divQ128(xQ, Q128);
        assertEq(result, xQ);
    }

    /// @dev divQ128(x, x) == Q128 (x/x = 1.0 in Q128.128)
    function testFuzz_divQ128_selfIsOne(uint64 x) public pure {
        vm.assume(x > 0);
        uint256 xQ = uint256(x);
        uint256 result = FixedPointMath.divQ128(xQ, xQ);
        assertEq(result, Q128);
    }

    /// @dev divQ128 reverts on zero denominator (via external wrapper)
    function testFuzz_divQ128_revertZero(uint128 a) public {
        vm.expectRevert("FixedPointMath: div by zero");
        w.divQ128(uint256(a), 0);
    }

    // ─── tanh ───

    /// @dev tanh(0) == 0
    function test_tanh_zero() public pure {
        assertEq(FixedPointMath.tanh(0), 0);
    }

    /// @dev tanh is monotonically non-decreasing
    function testFuzz_tanh_monotonic(uint128 a, uint128 b) public pure {
        uint256 x1 = uint256(a);
        uint256 x2 = uint256(b);
        if (x1 > x2) (x1, x2) = (x2, x1);
        assertLe(FixedPointMath.tanh(x1), FixedPointMath.tanh(x2));
    }

    /// @dev tanh(x) < Q128 for all x (tanh is bounded by 1.0)
    function testFuzz_tanh_boundedByOne(uint256 x) public pure {
        uint256 result = FixedPointMath.tanh(x);
        assertLt(result, Q128);
    }

    /// @dev tanh clamps for large x (>= 4.0 in Q128.128)
    function testFuzz_tanh_clampsAtFour(uint256 x) public pure {
        uint256 fourQ128 = 4 * Q128;
        vm.assume(x >= fourQ128);
        uint256 result = FixedPointMath.tanh(x);
        assertEq(result, 340054139448653691188148485995674998075);
    }

    /// @dev tanh grows quickly for small x (tanh(x) ≈ x for small x)
    function testFuzz_tanh_smallInputApprox(uint64 x) public pure {
        uint256 xQ = uint256(x);
        vm.assume(xQ > 0);
        vm.assume(xQ < Q128 / 100);
        uint256 result = FixedPointMath.tanh(xQ);
        uint256 diff = result > xQ ? result - xQ : xQ - result;
        assertLe(diff, xQ / 20 + 1);
    }

    // ─── tanhSigned ───

    /// @dev tanhSigned returns same magnitude as tanh
    function testFuzz_tanhSigned_magnitude(uint128 x, bool neg) public pure {
        (uint256 result, bool isNeg) = FixedPointMath.tanhSigned(uint256(x), neg);
        assertEq(result, FixedPointMath.tanh(uint256(x)));
        assertEq(isNeg, neg);
    }

    // ─── sqrt ───

    /// @dev sqrt(x)^2 <= x < (sqrt(x)+1)^2
    function testFuzz_sqrt_bounds(uint128 x) public pure {
        uint256 s = FixedPointMath.sqrt(uint256(x));
        assertLe(s * s, uint256(x));
        assertLt(uint256(x), (s + 1) * (s + 1));
    }

    /// @dev sqrt(0) == 0
    function test_sqrt_zero() public pure {
        assertEq(FixedPointMath.sqrt(0), 0);
    }

    /// @dev sqrt(1) == 1
    function test_sqrt_one() public pure {
        assertEq(FixedPointMath.sqrt(1), 1);
    }

    /// @dev sqrt of perfect squares
    function testFuzz_sqrt_perfectSquare(uint64 x) public pure {
        vm.assume(x > 0);
        uint256 sq = uint256(x) * uint256(x);
        assertEq(FixedPointMath.sqrt(sq), uint256(x));
    }

    // ─── min / max / absDiff ───

    function testFuzz_min(uint256 a, uint256 b) public pure {
        uint256 result = FixedPointMath.min(a, b);
        assertLe(result, a);
        assertLe(result, b);
        assertTrue(result == a || result == b);
    }

    function testFuzz_max(uint256 a, uint256 b) public pure {
        uint256 result = FixedPointMath.max(a, b);
        assertGe(result, a);
        assertGe(result, b);
        assertTrue(result == a || result == b);
    }

    function testFuzz_absDiff_symmetric(uint256 a, uint256 b) public pure {
        assertEq(FixedPointMath.absDiff(a, b), FixedPointMath.absDiff(b, a));
    }

    function testFuzz_absDiff_value(uint256 a, uint256 b) public pure {
        uint256 diff = FixedPointMath.absDiff(a, b);
        if (a >= b) {
            assertEq(diff, a - b);
        } else {
            assertEq(diff, b - a);
        }
    }
}
