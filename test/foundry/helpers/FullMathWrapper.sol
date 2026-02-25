// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../../../src/utils/FullMath.sol";

/// @dev External wrapper for FullMath so vm.expectRevert works with Forge
contract FullMathWrapper {
    function mulDiv(uint256 a, uint256 b, uint256 d) external pure returns (uint256) {
        return FullMath.mulDiv(a, b, d);
    }

    function mulDivRoundingUp(uint256 a, uint256 b, uint256 d) external pure returns (uint256) {
        return FullMath.mulDivRoundingUp(a, b, d);
    }
}
