// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../src/core/libraries/LibFee.sol";
import "../../src/core/interfaces/IFeeFacet.sol";
import "./helpers/LibFeeWrapper.sol";

contract LibFeeFuzzTest is Test {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant MAX_FEE_BPS = 5000;
    LibFeeWrapper internal w;

    function setUp() public {
        w = new LibFeeWrapper();
    }

    // ─── calculateProgressiveFee ───

    /// @dev Fee always >= baseFee (when baseFee <= MAX_FEE_BPS)
    function testFuzz_progressiveFee_geBaseFee(
        uint16 baseFee,
        uint16 maxImpactFee,
        uint64 tradeSize,
        uint64 poolLiquidity
    ) public pure {
        baseFee = uint16(bound(uint256(baseFee), 0, MAX_FEE_BPS));
        maxImpactFee = uint16(bound(uint256(maxImpactFee), 0, MAX_FEE_BPS));
        vm.assume(poolLiquidity > 0);

        uint256 fee = LibFee.calculateProgressiveFee(
            uint256(baseFee),
            uint256(maxImpactFee),
            uint256(tradeSize),
            uint256(poolLiquidity)
        );
        assertGe(fee, uint256(baseFee));
    }

    /// @dev Fee always <= MAX_FEE_BPS (5000 = 50%)
    function testFuzz_progressiveFee_capped(
        uint16 baseFee,
        uint16 maxImpactFee,
        uint64 tradeSize,
        uint64 poolLiquidity
    ) public pure {
        baseFee = uint16(bound(uint256(baseFee), 0, MAX_FEE_BPS));
        maxImpactFee = uint16(bound(uint256(maxImpactFee), 0, MAX_FEE_BPS));
        vm.assume(poolLiquidity > 0);

        uint256 fee = LibFee.calculateProgressiveFee(
            uint256(baseFee),
            uint256(maxImpactFee),
            uint256(tradeSize),
            uint256(poolLiquidity)
        );
        assertLe(fee, MAX_FEE_BPS);
    }

    /// @dev Zero trade size -> fee == baseFee (baseFee must be <= MAX_FEE_BPS for no cap)
    function testFuzz_progressiveFee_zeroTradeSize(uint16 baseFee, uint16 maxImpactFee, uint128 poolLiquidity) public pure {
        baseFee = uint16(bound(uint256(baseFee), 0, MAX_FEE_BPS));
        maxImpactFee = uint16(bound(uint256(maxImpactFee), 0, MAX_FEE_BPS));
        vm.assume(poolLiquidity > 0);

        uint256 fee = LibFee.calculateProgressiveFee(
            uint256(baseFee),
            uint256(maxImpactFee),
            0,
            uint256(poolLiquidity)
        );
        assertEq(fee, uint256(baseFee));
    }

    /// @dev Zero liquidity → fee == baseFee
    function testFuzz_progressiveFee_zeroLiquidity(uint16 baseFee, uint16 maxImpactFee, uint128 tradeSize) public pure {
        baseFee = uint16(bound(uint256(baseFee), 0, BPS));
        uint256 fee = LibFee.calculateProgressiveFee(
            uint256(baseFee),
            uint256(maxImpactFee),
            uint256(tradeSize),
            0
        );
        assertEq(fee, uint256(baseFee));
    }

    /// @dev Fee is monotonically non-decreasing with trade size
    function testFuzz_progressiveFee_monotonic(
        uint16 baseFee,
        uint16 maxImpactFee,
        uint64 tradeA,
        uint64 tradeB,
        uint128 poolLiquidity
    ) public pure {
        baseFee = uint16(bound(uint256(baseFee), 0, BPS));
        maxImpactFee = uint16(bound(uint256(maxImpactFee), 0, MAX_FEE_BPS));
        vm.assume(poolLiquidity > 0);
        uint256 a = uint256(tradeA);
        uint256 b = uint256(tradeB);
        if (a > b) (a, b) = (b, a);

        uint256 feeA = LibFee.calculateProgressiveFee(uint256(baseFee), uint256(maxImpactFee), a, uint256(poolLiquidity));
        uint256 feeB = LibFee.calculateProgressiveFee(uint256(baseFee), uint256(maxImpactFee), b, uint256(poolLiquidity));
        assertLe(feeA, feeB);
    }

    // ─── applyFee ───

    /// @dev netAmount + feeAmount == original amount
    function testFuzz_applyFee_conservation(uint128 amount, uint16 feeBps) public pure {
        feeBps = uint16(bound(uint256(feeBps), 0, BPS));
        (uint256 net, uint256 fee) = LibFee.applyFee(uint256(amount), uint256(feeBps));
        assertEq(net + fee, uint256(amount));
    }

    /// @dev Zero fee → net == amount
    function testFuzz_applyFee_zeroFee(uint128 amount) public pure {
        (uint256 net, uint256 fee) = LibFee.applyFee(uint256(amount), 0);
        assertEq(net, uint256(amount));
        assertEq(fee, 0);
    }

    /// @dev Full fee (10000 bps) → net == 0
    function testFuzz_applyFee_fullFee(uint128 amount) public pure {
        (uint256 net, uint256 fee) = LibFee.applyFee(uint256(amount), BPS);
        assertEq(net, 0);
        assertEq(fee, uint256(amount));
    }

    // ─── distributeFee ───

    /// @dev lpFee + protocolFee + traderFee == totalFee
    function testFuzz_distributeFee_conservation(uint128 totalFee) public pure {
        // Use default split: 70/20/10
        (uint256 lp, uint256 proto, uint256 trader) = LibFee.distributeFee(
            uint256(totalFee), 7000, 2000, 1000
        );
        assertEq(lp + proto + trader, uint256(totalFee));
    }

    /// @dev Shares with arbitrary valid split still sum to total
    function testFuzz_distributeFee_arbitrarySplit(
        uint128 totalFee,
        uint16 lpShare,
        uint16 protoShare
    ) public pure {
        // Ensure shares sum to BPS
        lpShare = uint16(bound(uint256(lpShare), 0, BPS));
        protoShare = uint16(bound(uint256(protoShare), 0, BPS - uint256(lpShare)));
        uint16 traderShare = uint16(BPS - uint256(lpShare) - uint256(protoShare));

        (uint256 lp, uint256 proto, uint256 trader) = LibFee.distributeFee(
            uint256(totalFee),
            uint256(lpShare),
            uint256(protoShare),
            uint256(traderShare)
        );
        assertEq(lp + proto + trader, uint256(totalFee));
    }

    // ─── validateFeeConfig ───

    /// @dev Valid default config doesn't revert
    function test_validateFeeConfig_default() public pure {
        IFeeFacet.FeeConfig memory config = LibFee.defaultFeeConfig();
        LibFee.validateFeeConfig(config);
    }

    /// @dev Invalid config (shares != BPS) reverts (via external wrapper)
    function testFuzz_validateFeeConfig_invalidShares(uint16 lpShare, uint16 protoShare, uint16 traderShare) public {
        vm.assume(uint256(lpShare) + uint256(protoShare) + uint256(traderShare) != BPS);
        IFeeFacet.FeeConfig memory config = IFeeFacet.FeeConfig({
            baseFee: 1,
            maxImpactFee: 100,
            lpShareBps: uint256(lpShare),
            protocolShareBps: uint256(protoShare),
            traderShareBps: uint256(traderShare)
        });
        vm.expectRevert(LibFee.InvalidFeeConfig.selector);
        w.validateFeeConfig(config);
    }
}
