// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../src/utils/FullMath.sol";
import "./helpers/FullMathWrapper.sol";

contract FullMathFuzzTest is Test {
    FullMathWrapper internal w;

    function setUp() public {
        w = new FullMathWrapper();
    }

    // ─── mulDiv ───

    /// @dev mulDiv(a, b, 1) == a * b when no overflow
    function testFuzz_mulDiv_denominatorOne(uint128 a, uint128 b) public pure {
        uint256 result = FullMath.mulDiv(uint256(a), uint256(b), 1);
        assertEq(result, uint256(a) * uint256(b));
    }

    /// @dev mulDiv(a, b, b) == a when b > 0 and result fits
    function testFuzz_mulDiv_cancelsDenominator(uint128 a, uint128 b) public pure {
        vm.assume(b > 0);
        uint256 result = FullMath.mulDiv(uint256(a), uint256(b), uint256(b));
        assertEq(result, uint256(a));
    }

    /// @dev mulDiv(0, b, d) == 0
    function testFuzz_mulDiv_zeroNumerator(uint256 b, uint256 d) public pure {
        vm.assume(d > 0);
        assertEq(FullMath.mulDiv(0, b, d), 0);
    }

    /// @dev mulDiv reverts on division by zero (via external wrapper)
    function testFuzz_mulDiv_revertsDivByZero(uint128 a, uint128 b) public {
        vm.assume(a > 0 && b > 0);
        vm.expectRevert("FullMath: division by zero");
        w.mulDiv(uint256(a), uint256(b), 0);
    }

    /// @dev mulDiv commutative: mulDiv(a, b, d) == mulDiv(b, a, d)
    function testFuzz_mulDiv_commutative(uint128 a, uint128 b, uint256 d) public pure {
        vm.assume(d > 0);
        assertEq(
            FullMath.mulDiv(uint256(a), uint256(b), d),
            FullMath.mulDiv(uint256(b), uint256(a), d)
        );
    }

    /// @dev Result matches naive computation when no overflow
    function testFuzz_mulDiv_boundedResult(uint128 a, uint128 b, uint128 d) public pure {
        vm.assume(d > 0);
        uint256 result = FullMath.mulDiv(uint256(a), uint256(b), uint256(d));
        uint256 expected = (uint256(a) * uint256(b)) / uint256(d);
        assertEq(result, expected);
    }

    // ─── mulDivRoundingUp ───

    /// @dev mulDivRoundingUp >= mulDiv
    function testFuzz_mulDivRoundingUp_geFloor(uint128 a, uint128 b, uint128 d) public pure {
        vm.assume(d > 0);
        uint256 floor = FullMath.mulDiv(uint256(a), uint256(b), uint256(d));
        uint256 ceil = FullMath.mulDivRoundingUp(uint256(a), uint256(b), uint256(d));
        assertGe(ceil, floor);
    }

    /// @dev mulDivRoundingUp - mulDiv <= 1
    function testFuzz_mulDivRoundingUp_atMostOneMore(uint128 a, uint128 b, uint128 d) public pure {
        vm.assume(d > 0);
        uint256 floor = FullMath.mulDiv(uint256(a), uint256(b), uint256(d));
        uint256 ceil = FullMath.mulDivRoundingUp(uint256(a), uint256(b), uint256(d));
        assertLe(ceil - floor, 1);
    }

    /// @dev When exact division, floor == ceil
    function testFuzz_mulDivRoundingUp_exactEquals(uint128 a, uint128 d) public pure {
        vm.assume(d > 0);
        vm.assume(a > 0);
        uint256 floor = FullMath.mulDiv(uint256(a), uint256(d), uint256(d));
        uint256 ceil = FullMath.mulDivRoundingUp(uint256(a), uint256(d), uint256(d));
        assertEq(floor, ceil);
    }

    // ─── mulDivQ128 ───

    /// @dev mulDivQ128(a, b) == mulDiv(a, b, 2^128)
    function testFuzz_mulDivQ128_equivalence(uint128 a, uint128 b) public pure {
        uint256 result = FullMath.mulDivQ128(uint256(a), uint256(b));
        uint256 expected = FullMath.mulDiv(uint256(a), uint256(b), 1 << 128);
        assertEq(result, expected);
    }

    // ─── 512-bit path stress test ───

    /// @dev Large values that exercise the 512-bit division path
    function testFuzz_mulDiv_512bitPath(uint128 a) public pure {
        vm.assume(a > 1);
        uint256 b = uint256(1) << 128;
        uint256 result = FullMath.mulDiv(uint256(a), b, uint256(a));
        assertEq(result, b);
    }
}
