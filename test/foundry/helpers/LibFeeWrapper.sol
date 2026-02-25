// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../../../src/core/libraries/LibFee.sol";
import "../../../src/core/interfaces/IFeeFacet.sol";

/// @dev External wrapper for LibFee so vm.expectRevert works with Forge
contract LibFeeWrapper {
    function calculateProgressiveFee(
        uint256 baseFee, uint256 maxImpactFee, uint256 tradeSize, uint256 poolLiquidity
    ) external pure returns (uint256) {
        return LibFee.calculateProgressiveFee(baseFee, maxImpactFee, tradeSize, poolLiquidity);
    }

    function applyFee(uint256 amount, uint256 feeBps) external pure returns (uint256, uint256) {
        return LibFee.applyFee(amount, feeBps);
    }

    function distributeFee(
        uint256 totalFee, uint256 lpShare, uint256 protoShare, uint256 traderShare
    ) external pure returns (uint256, uint256, uint256) {
        return LibFee.distributeFee(totalFee, lpShare, protoShare, traderShare);
    }

    function validateFeeConfig(IFeeFacet.FeeConfig memory config) external pure {
        LibFee.validateFeeConfig(config);
    }
}
