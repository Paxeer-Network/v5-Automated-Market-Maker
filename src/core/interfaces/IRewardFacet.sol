// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title IRewardFacet — Interface for LP loyalty and trader rebate incentives
/// @notice Combined time + volume multiplier for LPs; epoch-based rebates for traders
interface IRewardFacet {
    struct LPRewardInfo {
        uint256 loyaltyMultiplier;     // Current multiplier (Q128.128)
        uint256 accumulatedFees0;
        uint256 accumulatedFees1;
        uint256 depositTimestamp;
        uint256 cumulativeVolume;
    }

    struct TraderRewardInfo {
        uint256 currentEpoch;
        uint256 epochSwapCount;
        uint256 epochVolume;
        uint256 pendingRebate0;
        uint256 pendingRebate1;
    }

    struct EpochConfig {
        uint256 epochDuration;         // Duration in seconds (default: 7 days)
        uint256 minSwapsForRebate;     // Minimum swaps per epoch to qualify
        uint256 maxTradeSize;          // Max single trade size for rebate qualification (bps of pool)
    }

    event EpochAdvanced(uint256 indexed epoch, uint256 totalRebatePool0, uint256 totalRebatePool1);
    event LPRewardsClaimed(address indexed lp, uint256 positionId, uint256 amount0, uint256 amount1);
    event TraderRebateClaimed(address indexed trader, uint256 amount0, uint256 amount1);

    /// @notice Calculate the current loyalty multiplier for an LP position
    /// @param positionId The position identifier
    /// @return multiplier The loyalty multiplier (Q128.128)
    function getLPMultiplier(uint256 positionId) external view returns (uint256 multiplier);

    /// @notice Get reward info for an LP position
    function getLPRewardInfo(uint256 positionId) external view returns (LPRewardInfo memory);

    /// @notice Get reward info for a trader
    function getTraderRewardInfo(address trader) external view returns (TraderRewardInfo memory);

    /// @notice Claim trader rebates for completed epochs
    function claimTraderRebate(address recipient) external returns (uint256 amount0, uint256 amount1);

    /// @notice Advance to the next epoch (callable by anyone)
    function advanceEpoch() external;

    /// @notice Set epoch configuration (owner only)
    function setEpochConfig(EpochConfig calldata config) external;

    /// @notice Get current epoch info
    function getCurrentEpoch() external view returns (uint256 epoch, uint256 startTime, uint256 endTime);
}
