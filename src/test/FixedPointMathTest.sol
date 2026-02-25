// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../utils/FixedPointMath.sol";

/// @title FixedPointMathTest — Wrapper contract to test FixedPointMath library
contract FixedPointMathTest {
    function tanh(uint256 x) external pure returns (uint256) {
        return FixedPointMath.tanh(x);
    }

    function mulQ128(uint256 a, uint256 b) external pure returns (uint256) {
        return FixedPointMath.mulQ128(a, b);
    }

    function divQ128(uint256 a, uint256 b) external pure returns (uint256) {
        return FixedPointMath.divQ128(a, b);
    }

    function toQ128(uint256 x) external pure returns (uint256) {
        return FixedPointMath.toQ128(x);
    }

    function fromQ128(uint256 x) external pure returns (uint256) {
        return FixedPointMath.fromQ128(x);
    }

    function sqrt(uint256 x) external pure returns (uint256) {
        return FixedPointMath.sqrt(x);
    }

    function sqrtQ128(uint256 x) external pure returns (uint256) {
        return FixedPointMath.sqrtQ128(x);
    }

    function Q128() external pure returns (uint256) {
        return FixedPointMath.Q128;
    }
}
