// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../interfaces/IPool.sol";
import "../interfaces/ILiquidityFacet.sol";
import "../interfaces/IOrderFacet.sol";
import "../interfaces/IOracleFacet.sol";
import "../interfaces/IOraclePegFacet.sol";
import "../interfaces/IFeeFacet.sol";
import "../interfaces/IRewardFacet.sol";

/// @title AppStorage — Central storage struct for the Diamond (EIP-2535 pattern)
/// @notice All protocol state is stored in a single struct at a deterministic slot
/// @dev Custom implementation — no external dependencies

/// @dev Tick-aligned order bucket: FIFO queue of order IDs at a given tick
struct OrderBucket {
    uint256[] orderIds;
    uint256 headIndex; // Points to the first unprocessed order
}

/// @dev Oracle observation for TWAP ring buffer
struct Observation {
    uint32 blockTimestamp;
    int56 tickCumulative;
    uint160 secondsPerLiquidityCumulativeX128;
    bool initialized;
}

/// @dev Oracle observation buffer state
struct OracleState {
    uint16 index;
    uint16 cardinality;
    uint16 cardinalityNext;
}

/// @dev Tick-level state
struct TickInfo {
    uint128 liquidityGross;
    int128 liquidityNet;
    uint256 feeGrowthOutside0X128;
    uint256 feeGrowthOutside1X128;
    int56 tickCumulativeOutside;
    uint160 secondsPerLiquidityOutsideX128;
    uint32 secondsOutside;
    bool initialized;
}

/// @dev LP reward tracking per position
struct LPRewardState {
    uint256 depositTimestamp;
    uint256 cumulativeVolume;
    uint256 lastClaimEpoch;
}

/// @dev Trader reward tracking per address per pool
struct TraderRewardState {
    uint256 epochSwapCount;
    uint256 epochVolume;
    uint256 lastActiveEpoch;
    uint256 pendingRebate0;
    uint256 pendingRebate1;
}

/// @dev Epoch state for reward distribution
struct EpochState {
    uint256 currentEpoch;
    uint256 epochStartTime;
    uint256 epochDuration; // Default 7 days
    uint256 minSwapsForRebate; // Min swaps to qualify
    uint256 maxTradeSizeBps; // Max trade size for rebate (bps of pool)
    uint256 totalRebatePool0;
    uint256 totalRebatePool1;
}

struct AppStorage {
    // ──────────────── Pool State ────────────────
    mapping(bytes32 => IPool.PoolConfig) poolConfigs;
    mapping(bytes32 => IPool.PoolState) poolStates;
    mapping(bytes32 => IFeeFacet.FeeConfig) feeConfigs;
    bytes32[] poolIds;
    uint256 poolCount;
    // ──────────────── Tick State ────────────────
    mapping(bytes32 => mapping(int24 => TickInfo)) ticks;
    mapping(bytes32 => mapping(int16 => uint256)) tickBitmaps;
    // ──────────────── Position State ────────────────
    mapping(uint256 => ILiquidityFacet.Position) positions;
    uint256 nextPositionId;
    // ──────────────── Order Book State ────────────────
    mapping(uint256 => IOrderFacet.Order) orders;
    mapping(bytes32 => mapping(int24 => OrderBucket)) orderBuckets;
    mapping(bytes32 => uint256) activeOrderCounts;
    uint256 nextOrderId;
    uint256 maxOrdersPerPool;
    uint256 defaultOrderTTL; // Default: 30 days
    uint256 minOrderSize;
    uint256 keeperBountyBps; // Keeper bounty in bps (1 = 0.01%)
    // ──────────────── Oracle State (Internal TWAP) ────────────────
    mapping(bytes32 => Observation[65535]) observations;
    mapping(bytes32 => OracleState) oracleStates;
    // ──────────────── Oracle Peg State ────────────────
    mapping(bytes32 => IOraclePegFacet.PegConfig) pegConfigs;
    mapping(bytes32 => bool) isPeggedPool;
    // ──────────────── Reward State ────────────────
    mapping(uint256 => LPRewardState) lpRewards; // positionId => state
    mapping(bytes32 => mapping(address => TraderRewardState)) traderRewards; // poolId => trader => state
    EpochState epochState;
    // ──────────────── Flash Loan State ────────────────
    uint256 flashLoanFeeBps; // Default: 9 (0.09%)
    // ──────────────── Protocol State ────────────────
    address treasury;
    bool paused;
    mapping(address => bool) pauseGuardians;
    // ──────────────── Pool Factory State ────────────────
    mapping(bytes32 => address) poolCreators; // poolId => creator address
    address eventEmitter; // Protocol EventEmitter contract
    // ──────────────── Reentrancy Guard ────────────────
    uint256 reentrancyStatus;
}

/// @notice Storage access helper
library LibAppStorage {
    bytes32 constant APP_STORAGE_POSITION = keccak256("v5asamm.app.storage");

    function appStorage() internal pure returns (AppStorage storage s) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}
