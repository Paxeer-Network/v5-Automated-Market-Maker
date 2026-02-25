// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../../utils/FixedPointMath.sol";
import "../../utils/FullMath.sol";
import "../storage/AppStorage.sol";

/// @title LibReward — LP loyalty multiplier and trader rebate calculations
/// @notice multiplier = time_factor * sqrt(volume_factor)
/// @dev Custom implementation — no external dependencies
library LibReward {
    uint256 internal constant Q128 = 1 << 128;
    uint256 internal constant BPS = 10_000;

    // Time tier thresholds (in seconds)
    uint256 internal constant TIER_1_THRESHOLD = 30 days;
    uint256 internal constant TIER_2_THRESHOLD = 90 days;
    uint256 internal constant TIER_3_THRESHOLD = 180 days;

    // Time tier multipliers in Q128.128 (1.0x, 1.25x, 1.5x, 2.0x)
    uint256 internal constant TIME_FACTOR_TIER_0 = Q128; // 1.00x
    uint256 internal constant TIME_FACTOR_TIER_1 = Q128 + (Q128 / 4); // 1.25x
    uint256 internal constant TIME_FACTOR_TIER_2 = Q128 + (Q128 / 2); // 1.50x
    uint256 internal constant TIME_FACTOR_TIER_3 = 2 * Q128; // 2.00x

    // Volume factor cap (3.0x in Q128.128)
    uint256 internal constant MAX_VOLUME_FACTOR = 3 * Q128;

    /// @notice Calculate the time-based loyalty factor for an LP position
    /// @param depositTimestamp When the LP deposited
    /// @return timeFactor The time factor in Q128.128
    function calculateTimeFactor(uint256 depositTimestamp) internal view returns (uint256 timeFactor) {
        uint256 duration = block.timestamp - depositTimestamp;

        if (duration >= TIER_3_THRESHOLD) {
            timeFactor = TIME_FACTOR_TIER_3;
        } else if (duration >= TIER_2_THRESHOLD) {
            timeFactor = TIME_FACTOR_TIER_2;
        } else if (duration >= TIER_1_THRESHOLD) {
            timeFactor = TIME_FACTOR_TIER_1;
        } else {
            timeFactor = TIME_FACTOR_TIER_0;
        }
    }

    /// @notice Calculate the volume-based factor for an LP position
    /// @dev volumeFactor = min(lp_liquidity / average_lp_liquidity, 3.0)
    /// @param positionLiquidity The LP's liquidity amount
    /// @param averageLiquidity The average LP liquidity across all positions
    /// @return volumeFactor The volume factor in Q128.128
    function calculateVolumeFactor(
        uint128 positionLiquidity,
        uint128 averageLiquidity
    ) internal pure returns (uint256 volumeFactor) {
        if (averageLiquidity == 0) return Q128; // Default to 1.0x

        // ratio = positionLiquidity / averageLiquidity in Q128.128
        volumeFactor = FullMath.mulDiv(uint256(positionLiquidity), Q128, uint256(averageLiquidity));

        // Cap at 3.0x
        if (volumeFactor > MAX_VOLUME_FACTOR) {
            volumeFactor = MAX_VOLUME_FACTOR;
        }
    }

    /// @notice Calculate the combined loyalty multiplier
    /// @dev multiplier = time_factor * sqrt(volume_factor)
    /// @param depositTimestamp When the LP deposited
    /// @param positionLiquidity The LP's liquidity
    /// @param averageLiquidity The average LP liquidity
    /// @return multiplier The combined multiplier in Q128.128
    function calculateLoyaltyMultiplier(
        uint256 depositTimestamp,
        uint128 positionLiquidity,
        uint128 averageLiquidity
    ) internal view returns (uint256 multiplier) {
        uint256 timeFactor = calculateTimeFactor(depositTimestamp);
        uint256 volumeFactor = calculateVolumeFactor(positionLiquidity, averageLiquidity);

        // sqrt of volumeFactor in Q128.128
        uint256 sqrtVolume = FixedPointMath.sqrtQ128(volumeFactor);

        // multiplier = timeFactor * sqrt(volumeFactor)
        multiplier = FixedPointMath.mulQ128(timeFactor, sqrtVolume);
    }

    /// @notice Apply the loyalty multiplier to a fee amount
    /// @param baseFeeAmount The base fee amount owed to the LP
    /// @param multiplier The loyalty multiplier (Q128.128)
    /// @return adjustedFee The adjusted fee amount
    function applyMultiplier(uint256 baseFeeAmount, uint256 multiplier) internal pure returns (uint256 adjustedFee) {
        adjustedFee = FullMath.mulDiv(baseFeeAmount, multiplier, Q128);
    }

    /// @notice Check if a trader qualifies for rebates in the current epoch
    /// @param swapCount Number of swaps in the epoch
    /// @param minSwaps Minimum required swaps
    /// @return qualifies Whether the trader qualifies
    function traderQualifiesForRebate(uint256 swapCount, uint256 minSwaps) internal pure returns (bool qualifies) {
        qualifies = swapCount >= minSwaps;
    }

    /// @notice Calculate a trader's share of the rebate pool
    /// @param traderVolume The trader's qualifying volume in the epoch
    /// @param totalQualifyingVolume Total qualifying volume from all traders
    /// @param rebatePool The total rebate pool amount
    /// @return rebateAmount The trader's rebate share
    function calculateTraderRebate(
        uint256 traderVolume,
        uint256 totalQualifyingVolume,
        uint256 rebatePool
    ) internal pure returns (uint256 rebateAmount) {
        if (totalQualifyingVolume == 0) return 0;
        rebateAmount = FullMath.mulDiv(rebatePool, traderVolume, totalQualifyingVolume);
    }

    /// @notice Check if the current epoch has ended and should advance
    /// @return shouldAdvance Whether the epoch should advance
    function shouldAdvanceEpoch() internal view returns (bool shouldAdvance) {
        AppStorage storage s = LibAppStorage.appStorage();
        EpochState storage epoch = s.epochState;
        shouldAdvance = block.timestamp >= epoch.epochStartTime + epoch.epochDuration;
    }
}
