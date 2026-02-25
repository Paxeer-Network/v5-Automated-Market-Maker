// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../interfaces/IRewardFacet.sol";
import "../interfaces/ILiquidityFacet.sol";
import "../libraries/LibReward.sol";
import "../libraries/LibSecurity.sol";
import "../libraries/LibTransfer.sol";
import "../storage/AppStorage.sol";
import "../../utils/FullMath.sol";

/// @title RewardFacet — LP loyalty multiplier and trader rebate management
/// @notice Combined time + volume multiplier for LPs; epoch-based rebates for traders
/// @dev Diamond facet — operates on AppStorage via delegatecall
contract RewardFacet is IRewardFacet {
    /// @inheritdoc IRewardFacet
    function getLPMultiplier(uint256 positionId) external view returns (uint256 multiplier) {
        AppStorage storage s = LibAppStorage.appStorage();
        ILiquidityFacet.Position storage pos = s.positions[positionId];
        require(pos.owner != address(0), "RewardFacet: position does not exist");

        // Calculate average liquidity across all positions (simplified)
        IPool.PoolState storage state = s.poolStates[pos.poolId];
        uint128 averageLiquidity = state.liquidity > 0 ? state.liquidity / 10 : 1; // Rough estimate

        multiplier = LibReward.calculateLoyaltyMultiplier(pos.depositTimestamp, pos.liquidity, averageLiquidity);
    }

    /// @inheritdoc IRewardFacet
    function getLPRewardInfo(uint256 positionId) external view returns (LPRewardInfo memory) {
        AppStorage storage s = LibAppStorage.appStorage();
        LPRewardState storage state = s.lpRewards[positionId];
        ILiquidityFacet.Position storage pos = s.positions[positionId];

        IPool.PoolState storage poolState = s.poolStates[pos.poolId];
        uint128 averageLiquidity = poolState.liquidity > 0 ? poolState.liquidity / 10 : 1;

        uint256 multiplier = LibReward.calculateLoyaltyMultiplier(
            state.depositTimestamp,
            pos.liquidity,
            averageLiquidity
        );

        return
            LPRewardInfo({
                loyaltyMultiplier: multiplier,
                accumulatedFees0: pos.tokensOwed0,
                accumulatedFees1: pos.tokensOwed1,
                depositTimestamp: state.depositTimestamp,
                cumulativeVolume: state.cumulativeVolume
            });
    }

    /// @inheritdoc IRewardFacet
    function getTraderRewardInfo(address trader) external view returns (TraderRewardInfo memory info) {
        AppStorage storage s = LibAppStorage.appStorage();
        // Return info for the first pool (simplified — in production would aggregate)
        if (s.poolCount > 0) {
            bytes32 poolId = s.poolIds[0];
            TraderRewardState storage state = s.traderRewards[poolId][trader];
            info = TraderRewardInfo({
                currentEpoch: s.epochState.currentEpoch,
                epochSwapCount: state.epochSwapCount,
                epochVolume: state.epochVolume,
                pendingRebate0: state.pendingRebate0,
                pendingRebate1: state.pendingRebate1
            });
        }
    }

    /// @inheritdoc IRewardFacet
    function claimTraderRebate(address recipient) external returns (uint256 amount0, uint256 amount1) {
        LibSecurity.nonReentrantBefore();

        AppStorage storage s = LibAppStorage.appStorage();

        // Iterate over pools and collect pending rebates
        for (uint256 i = 0; i < s.poolCount; i++) {
            bytes32 poolId = s.poolIds[i];
            TraderRewardState storage state = s.traderRewards[poolId][msg.sender];

            amount0 += state.pendingRebate0;
            amount1 += state.pendingRebate1;

            state.pendingRebate0 = 0;
            state.pendingRebate1 = 0;
        }

        // Transfer rebates
        if (amount0 > 0 && s.poolCount > 0) {
            IPool.PoolConfig storage config = s.poolConfigs[s.poolIds[0]];
            LibTransfer.pushToken(config.token0, recipient, amount0);
        }
        if (amount1 > 0 && s.poolCount > 0) {
            IPool.PoolConfig storage config = s.poolConfigs[s.poolIds[0]];
            LibTransfer.pushToken(config.token1, recipient, amount1);
        }

        emit TraderRebateClaimed(msg.sender, amount0, amount1);

        LibSecurity.nonReentrantAfter();
    }

    /// @inheritdoc IRewardFacet
    function advanceEpoch() external {
        AppStorage storage s = LibAppStorage.appStorage();
        EpochState storage epoch = s.epochState;

        require(LibReward.shouldAdvanceEpoch(), "RewardFacet: epoch not ended");

        emit EpochAdvanced(epoch.currentEpoch, epoch.totalRebatePool0, epoch.totalRebatePool1);

        // Reset for new epoch
        epoch.currentEpoch++;
        epoch.epochStartTime = block.timestamp;
        epoch.totalRebatePool0 = 0;
        epoch.totalRebatePool1 = 0;
    }

    /// @inheritdoc IRewardFacet
    function setEpochConfig(EpochConfig calldata config) external {
        LibSecurity.requireOwner();

        AppStorage storage s = LibAppStorage.appStorage();
        require(config.epochDuration >= 1 days, "RewardFacet: epoch too short");
        require(config.minSwapsForRebate > 0, "RewardFacet: min swaps zero");

        s.epochState.epochDuration = config.epochDuration;
        s.epochState.minSwapsForRebate = config.minSwapsForRebate;
        s.epochState.maxTradeSizeBps = config.maxTradeSize;
    }

    /// @inheritdoc IRewardFacet
    function getCurrentEpoch() external view returns (uint256 epoch, uint256 startTime, uint256 endTime) {
        AppStorage storage s = LibAppStorage.appStorage();
        epoch = s.epochState.currentEpoch;
        startTime = s.epochState.epochStartTime;
        endTime = startTime + s.epochState.epochDuration;
    }
}

import "../interfaces/IPool.sol";
