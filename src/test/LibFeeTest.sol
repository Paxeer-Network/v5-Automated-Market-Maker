// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../core/libraries/LibFee.sol";
import "../core/interfaces/IFeeFacet.sol";

/// @title LibFeeTest — Wrapper contract to test the LibFee library
contract LibFeeTest {
    function calculateProgressiveFee(
        uint256 baseFee,
        uint256 maxImpactFee,
        uint256 tradeSize,
        uint256 poolLiquidity
    ) external pure returns (uint256) {
        return LibFee.calculateProgressiveFee(baseFee, maxImpactFee, tradeSize, poolLiquidity);
    }

    function applyFee(uint256 amount, uint256 feeBps) external pure returns (uint256 netAmount, uint256 feeAmount) {
        return LibFee.applyFee(amount, feeBps);
    }

    function distributeFee(
        uint256 totalFee,
        uint256 lpShareBps,
        uint256 protocolShareBps,
        uint256 traderShareBps
    ) external pure returns (uint256 lpFee, uint256 protocolFee, uint256 traderFee) {
        return LibFee.distributeFee(totalFee, lpShareBps, protocolShareBps, traderShareBps);
    }

    function validateFeeConfig(IFeeFacet.FeeConfig memory config) external pure {
        LibFee.validateFeeConfig(config);
    }

    function defaultFeeConfig() external pure returns (IFeeFacet.FeeConfig memory) {
        return LibFee.defaultFeeConfig();
    }
}
