// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../../../src/utils/SqrtPriceMath.sol";

/// @dev External wrapper for SqrtPriceMath so vm.expectRevert works with Forge
contract SqrtPriceMathWrapper {
    function getAmount0Delta(uint160 a, uint160 b, uint128 liq, bool up) external pure returns (uint256) {
        return SqrtPriceMath.getAmount0Delta(a, b, liq, up);
    }

    function getAmount1Delta(uint160 a, uint160 b, uint128 liq, bool up) external pure returns (uint256) {
        return SqrtPriceMath.getAmount1Delta(a, b, liq, up);
    }

    function getNextSqrtPriceFromInput(uint160 p, uint128 liq, uint256 amt, bool z) external pure returns (uint160) {
        return SqrtPriceMath.getNextSqrtPriceFromInput(p, liq, amt, z);
    }

    function getNextSqrtPriceFromOutput(uint160 p, uint128 liq, uint256 amt, bool z) external pure returns (uint160) {
        return SqrtPriceMath.getNextSqrtPriceFromOutput(p, liq, amt, z);
    }
}
