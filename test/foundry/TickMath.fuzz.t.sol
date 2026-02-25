// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../src/utils/TickMath.sol";
import "./helpers/TickMathWrapper.sol";

contract TickMathFuzzTest is Test {
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = 887272;
    uint160 internal constant MIN_SQRT_PRICE = 4295128739;
    uint160 internal constant MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342;

    TickMathWrapper internal w;

    function setUp() public {
        w = new TickMathWrapper();
    }

    // ─── getSqrtPriceAtTick ───

    /// @dev Result is always within [MIN_SQRT_PRICE, MAX_SQRT_PRICE]
    function testFuzz_getSqrtPriceAtTick_inRange(int24 tick) public pure {
        tick = int24(bound(int256(tick), int256(MIN_TICK), int256(MAX_TICK)));
        uint160 price = TickMath.getSqrtPriceAtTick(tick);
        assertGe(price, MIN_SQRT_PRICE);
        assertLe(price, MAX_SQRT_PRICE);
    }

    /// @dev Monotonicity: higher tick -> higher sqrt price
    function testFuzz_getSqrtPriceAtTick_monotonic(int24 a, int24 b) public pure {
        a = int24(bound(int256(a), int256(MIN_TICK), int256(MAX_TICK)));
        b = int24(bound(int256(b), int256(MIN_TICK), int256(MAX_TICK)));
        if (a > b) (a, b) = (b, a);
        uint160 priceA = TickMath.getSqrtPriceAtTick(a);
        uint160 priceB = TickMath.getSqrtPriceAtTick(b);
        assertLe(priceA, priceB);
    }

    /// @dev tick(0) should give sqrtPrice = 2^96 (price = 1.0)
    function test_getSqrtPriceAtTick_zero() public pure {
        uint160 price = TickMath.getSqrtPriceAtTick(0);
        assertEq(price, 79228162514264337593543950336);
    }

    /// @dev Reverts for out-of-range ticks (via external wrapper)
    function testFuzz_getSqrtPriceAtTick_revertsOutOfRange(int24 tick) public {
        vm.assume(tick < MIN_TICK || tick > MAX_TICK);
        vm.expectRevert("TickMath: tick out of range");
        w.getSqrtPriceAtTick(tick);
    }

    // ─── getTickAtSqrtPrice ───

    /// @dev Result is always within [MIN_TICK, MAX_TICK]
    function testFuzz_getTickAtSqrtPrice_inRange(uint160 sqrtPriceX96) public pure {
        sqrtPriceX96 = uint160(bound(uint256(sqrtPriceX96), uint256(MIN_SQRT_PRICE), uint256(MAX_SQRT_PRICE) - 1));
        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);
        assertGe(tick, MIN_TICK);
        assertLe(tick, MAX_TICK);
    }

    /// @dev Monotonicity: higher price -> higher or equal tick
    function testFuzz_getTickAtSqrtPrice_monotonic(uint160 a, uint160 b) public pure {
        a = uint160(bound(uint256(a), uint256(MIN_SQRT_PRICE), uint256(MAX_SQRT_PRICE) - 1));
        b = uint160(bound(uint256(b), uint256(MIN_SQRT_PRICE), uint256(MAX_SQRT_PRICE) - 1));
        if (a > b) (a, b) = (b, a);
        int24 tickA = TickMath.getTickAtSqrtPrice(a);
        int24 tickB = TickMath.getTickAtSqrtPrice(b);
        assertLe(tickA, tickB);
    }

    // ─── Round-trip consistency ───

    /// @dev getSqrtPriceAtTick(getTickAtSqrtPrice(p)) <= p (floor property)
    function testFuzz_roundTrip_priceToTick(uint160 sqrtPriceX96) public pure {
        sqrtPriceX96 = uint160(bound(uint256(sqrtPriceX96), uint256(MIN_SQRT_PRICE), uint256(MAX_SQRT_PRICE) - 1));
        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);
        uint160 recoveredPrice = TickMath.getSqrtPriceAtTick(tick);
        assertLe(recoveredPrice, sqrtPriceX96);
    }

    /// @dev getTickAtSqrtPrice(getSqrtPriceAtTick(t)) is within [-1, 0] of t
    ///      Due to rounding in the ceiling division in getSqrtPriceAtTick,
    ///      the recovered tick may be t or t-1
    function testFuzz_roundTrip_tickToPrice(int24 tick) public pure {
        tick = int24(bound(int256(tick), int256(MIN_TICK), int256(MAX_TICK)));
        uint160 price = TickMath.getSqrtPriceAtTick(tick);
        if (price >= MAX_SQRT_PRICE) return;
        int24 recovered = TickMath.getTickAtSqrtPrice(price);
        // The recovered tick should be tick or tick-1 due to floor rounding
        assertTrue(recovered == tick || recovered == tick - 1);
    }

    // ─── nearestUsableTick ───

    /// @dev Result is always a multiple of tickSpacing
    function testFuzz_nearestUsableTick_aligned(int24 tick, int24 spacing) public pure {
        spacing = int24(bound(int256(spacing), 1, 16384));
        tick = int24(bound(int256(tick), int256(MIN_TICK), int256(MAX_TICK)));
        int24 aligned = TickMath.nearestUsableTick(tick, spacing);
        assertEq(aligned % spacing, 0);
    }

    /// @dev Aligned tick is always <= original tick
    function testFuzz_nearestUsableTick_floorsDown(int24 tick, int24 spacing) public pure {
        spacing = int24(bound(int256(spacing), 1, 16384));
        tick = int24(bound(int256(tick), int256(MIN_TICK), int256(MAX_TICK)));
        int24 aligned = TickMath.nearestUsableTick(tick, spacing);
        assertLe(aligned, tick);
    }

    /// @dev Spacing must be positive (via external wrapper)
    function test_nearestUsableTick_revertsZeroSpacing() public {
        vm.expectRevert("TickMath: spacing must be positive");
        w.nearestUsableTick(100, 0);
    }
}
