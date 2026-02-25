// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../../../src/utils/FixedPointMath.sol";

/// @dev External wrapper for FixedPointMath so vm.expectRevert works with Forge
contract FixedPointMathWrapper {
    function divQ128(uint256 a, uint256 b) external pure returns (uint256) {
        return FixedPointMath.divQ128(a, b);
    }

    function mulQ128(uint256 a, uint256 b) external pure returns (uint256) {
        return FixedPointMath.mulQ128(a, b);
    }

    function tanh(uint256 x) external pure returns (uint256) {
        return FixedPointMath.tanh(x);
    }

    function sqrt(uint256 x) external pure returns (uint256) {
        return FixedPointMath.sqrt(x);
    }
}
