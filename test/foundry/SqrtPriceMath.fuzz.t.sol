// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../src/utils/SqrtPriceMath.sol";
import "../../src/utils/TickMath.sol";
import "./helpers/SqrtPriceMathWrapper.sol";

contract SqrtPriceMathFuzzTest is Test {
    uint160 internal constant MIN_SQRT_PRICE = 4295128739;
    uint160 internal constant MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342;
    // A realistic "middle" price: sqrtPrice at tick 0 = 2^96
    uint160 internal constant MID_PRICE = 79228162514264337593543950336;

    SqrtPriceMathWrapper internal w;

    function setUp() public {
        w = new SqrtPriceMathWrapper();
    }

    // ─── getAmount0Delta ───

    /// @dev amount0 == 0 when priceA == priceB
    function testFuzz_getAmount0Delta_samePrice(uint160 price, uint128 liquidity) public pure {
        price = uint160(bound(uint256(price), uint256(MIN_SQRT_PRICE), uint256(MAX_SQRT_PRICE)));
        uint256 result = SqrtPriceMath.getAmount0Delta(price, price, liquidity, false);
        assertEq(result, 0);
    }

    /// @dev amount0 with roundUp >= amount0 without roundUp
    ///      Use realistic price range (ticks -50000 to +50000) and bounded liquidity
    function testFuzz_getAmount0Delta_roundUpGe(int24 tickA, int24 tickB, uint48 liquidity) public pure {
        tickA = int24(bound(int256(tickA), -50000, 50000));
        tickB = int24(bound(int256(tickB), -50000, 50000));
        vm.assume(liquidity > 0);
        uint160 priceA = TickMath.getSqrtPriceAtTick(tickA);
        uint160 priceB = TickMath.getSqrtPriceAtTick(tickB);
        uint256 floor = SqrtPriceMath.getAmount0Delta(priceA, priceB, uint128(liquidity), false);
        uint256 ceil = SqrtPriceMath.getAmount0Delta(priceA, priceB, uint128(liquidity), true);
        assertGe(ceil, floor);
    }

    /// @dev amount0 is symmetric in price ordering
    function testFuzz_getAmount0Delta_symmetric(int24 tickA, int24 tickB, uint48 liquidity) public pure {
        tickA = int24(bound(int256(tickA), -50000, 50000));
        tickB = int24(bound(int256(tickB), -50000, 50000));
        uint160 priceA = TickMath.getSqrtPriceAtTick(tickA);
        uint160 priceB = TickMath.getSqrtPriceAtTick(tickB);
        assertEq(
            SqrtPriceMath.getAmount0Delta(priceA, priceB, uint128(liquidity), false),
            SqrtPriceMath.getAmount0Delta(priceB, priceA, uint128(liquidity), false)
        );
    }

    // ─── getAmount1Delta ───

    /// @dev amount1 == 0 when priceA == priceB
    function testFuzz_getAmount1Delta_samePrice(uint160 price, uint128 liquidity) public pure {
        price = uint160(bound(uint256(price), uint256(MIN_SQRT_PRICE), uint256(MAX_SQRT_PRICE)));
        uint256 result = SqrtPriceMath.getAmount1Delta(price, price, liquidity, false);
        assertEq(result, 0);
    }

    /// @dev amount1 with roundUp >= amount1 without roundUp
    function testFuzz_getAmount1Delta_roundUpGe(int24 tickA, int24 tickB, uint64 liquidity) public pure {
        tickA = int24(bound(int256(tickA), -50000, 50000));
        tickB = int24(bound(int256(tickB), -50000, 50000));
        vm.assume(liquidity > 0);
        uint160 priceA = TickMath.getSqrtPriceAtTick(tickA);
        uint160 priceB = TickMath.getSqrtPriceAtTick(tickB);
        uint256 floor = SqrtPriceMath.getAmount1Delta(priceA, priceB, uint128(liquidity), false);
        uint256 ceil = SqrtPriceMath.getAmount1Delta(priceA, priceB, uint128(liquidity), true);
        assertGe(ceil, floor);
    }

    // ─── getNextSqrtPriceFromInput ───

    /// @dev Adding zero input returns same price
    function testFuzz_getNextSqrtPriceFromInput_zeroAmount(uint160 price, uint128 liquidity, bool zeroForOne) public pure {
        price = uint160(bound(uint256(price), uint256(MIN_SQRT_PRICE), uint256(MAX_SQRT_PRICE)));
        liquidity = uint128(bound(uint256(liquidity), 1, type(uint128).max));
        uint160 next = SqrtPriceMath.getNextSqrtPriceFromInput(price, liquidity, 0, zeroForOne);
        assertEq(next, price);
    }

    /// @dev token0 input (zeroForOne=true) decreases price
    ///      Bound amount so amount * sqrtPriceX96 doesn't overflow uint256
    function testFuzz_getNextSqrtPriceFromInput_token0DecreasesPrice(int24 tick, uint48 liquidity, uint32 amount) public pure {
        tick = int24(bound(int256(tick), -50000, 50000));
        vm.assume(liquidity > 0);
        vm.assume(amount > 0);
        uint160 price = TickMath.getSqrtPriceAtTick(tick);
        uint160 next = SqrtPriceMath.getNextSqrtPriceFromInput(price, uint128(liquidity), uint256(amount), true);
        assertLe(next, price);
    }

    /// @dev token1 input (zeroForOne=false) increases price
    ///      The result sqrtPrice + quotient must fit in uint160, so bound amount relative to liquidity
    function testFuzz_getNextSqrtPriceFromInput_token1IncreasesPrice(int24 tick, uint64 liquidity, uint64 amount) public pure {
        tick = int24(bound(int256(tick), -50000, 50000));
        vm.assume(liquidity > 0);
        vm.assume(amount > 0);
        // Ensure the added quotient doesn't overflow uint160:
        // quotient = (amount << 96) / liquidity, we need sqrtPrice + quotient < 2^160
        // Bound amount to be at most liquidity to keep quotient reasonable
        amount = uint64(bound(uint256(amount), 1, uint256(liquidity)));
        uint160 price = TickMath.getSqrtPriceAtTick(tick);
        uint160 next = SqrtPriceMath.getNextSqrtPriceFromInput(price, uint128(liquidity), uint256(amount), false);
        assertGe(next, price);
    }

    /// @dev Reverts with zero liquidity (via external wrapper)
    function testFuzz_getNextSqrtPriceFromInput_revertsZeroLiquidity(uint64 amount) public {
        vm.expectRevert("SqrtPriceMath: liquidity zero");
        w.getNextSqrtPriceFromInput(MID_PRICE, 0, uint256(amount), true);
    }

    // ─── getNextSqrtPriceFromOutput ───

    /// @dev Adding zero output returns same price
    function testFuzz_getNextSqrtPriceFromOutput_zeroAmount(uint160 price, uint128 liquidity, bool zeroForOne) public pure {
        price = uint160(bound(uint256(price), uint256(MIN_SQRT_PRICE), uint256(MAX_SQRT_PRICE)));
        liquidity = uint128(bound(uint256(liquidity), 1, type(uint128).max));
        uint160 next = SqrtPriceMath.getNextSqrtPriceFromOutput(price, liquidity, 0, zeroForOne);
        assertEq(next, price);
    }

    /// @dev token0->token1 output (zeroForOne=true) decreases price
    ///      Output removes token1, so quotient = (amount << 96) / liquidity must be < sqrtPrice
    function testFuzz_getNextSqrtPriceFromOutput_token0DecreasesPrice(int24 tick, uint64 liquidity, uint64 amount) public pure {
        tick = int24(bound(int256(tick), -10000, 50000));
        // Need large liquidity relative to amount to avoid underflow
        liquidity = uint64(bound(uint256(liquidity), 1e9, type(uint64).max));
        vm.assume(amount > 0);
        // Bound amount so quotient < sqrtPrice to avoid underflow
        // quotient ≈ amount * 2^96 / liquidity. Keep amount << liquidity
        amount = uint64(bound(uint256(amount), 1, uint256(liquidity) / 1e6));
        vm.assume(amount > 0);
        uint160 price = TickMath.getSqrtPriceAtTick(tick);
        uint160 next = SqrtPriceMath.getNextSqrtPriceFromOutput(price, uint128(liquidity), uint256(amount), true);
        assertLe(next, price);
    }
}
