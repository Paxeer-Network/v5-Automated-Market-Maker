// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../../../src/utils/TickMath.sol";

/// @dev External wrapper for TickMath so vm.expectRevert works with Forge
contract TickMathWrapper {
    function getSqrtPriceAtTick(int24 tick) external pure returns (uint160) {
        return TickMath.getSqrtPriceAtTick(tick);
    }

    function getTickAtSqrtPrice(uint160 sqrtPriceX96) external pure returns (int24) {
        return TickMath.getTickAtSqrtPrice(sqrtPriceX96);
    }

    function nearestUsableTick(int24 tick, int24 spacing) external pure returns (int24) {
        return TickMath.nearestUsableTick(tick, spacing);
    }
}
