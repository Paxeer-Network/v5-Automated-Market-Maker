// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../utils/FullMath.sol";

/// @title FullMathTest — Wrapper contract to test the FullMath library
contract FullMathTest {
    function mulDiv(uint256 a, uint256 b, uint256 denominator) external pure returns (uint256) {
        return FullMath.mulDiv(a, b, denominator);
    }

    function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) external pure returns (uint256) {
        return FullMath.mulDivRoundingUp(a, b, denominator);
    }

    function mulDivQ128(uint256 a, uint256 b) external pure returns (uint256) {
        return FullMath.mulDivQ128(a, b);
    }
}
