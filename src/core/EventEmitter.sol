// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "./interfaces/IPool.sol";
import "./interfaces/IFeeFacet.sol";
import "./interfaces/ILiquidityFacet.sol";

/// @title IEventEmitter — Interface for the protocol event emitter
interface IEventEmitter {
    // ──────────────── Pool Events ────────────────
    event PoolCreatedDetailed(
        bytes32 indexed poolId,
        address indexed creator,
        address token0,
        address token1,
        uint24 tickSpacing,
        IPool.PoolType poolType,
        uint256 baseFee,
        uint256 maxImpactFee,
        uint256 timestamp
    );

    event PoolInitializedDetailed(bytes32 indexed poolId, uint160 sqrtPriceX96, int24 tick, uint256 timestamp);

    // ──────────────── Swap Events ────────────────
    event SwapExecuted(
        bytes32 indexed poolId,
        address indexed sender,
        address indexed recipient,
        bool zeroForOne,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96Before,
        uint160 sqrtPriceX96After,
        int24 tickBefore,
        int24 tickAfter,
        uint128 liquidity,
        uint256 feeAmount,
        uint256 timestamp
    );

    // ──────────────── Liquidity Events ────────────────
    event LiquidityAddedDetailed(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 indexed positionId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1,
        uint256 reserve0After,
        uint256 reserve1After,
        uint128 totalLiquidityAfter,
        uint256 timestamp
    );

    event LiquidityRemovedDetailed(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 indexed positionId,
        uint128 liquidityRemoved,
        uint256 amount0,
        uint256 amount1,
        uint256 reserve0After,
        uint256 reserve1After,
        uint128 totalLiquidityAfter,
        uint256 timestamp
    );

    // ──────────────── Fee Events ────────────────
    event FeesCollectedDetailed(
        bytes32 indexed poolId,
        address indexed collector,
        uint256 amount0,
        uint256 amount1,
        uint256 protocolFees0Remaining,
        uint256 protocolFees1Remaining,
        uint256 timestamp
    );

    // ──────────────── Pool Snapshot ────────────────
    event PoolSnapshot(
        bytes32 indexed poolId,
        uint160 sqrtPriceX96,
        int24 currentTick,
        uint128 liquidity,
        uint256 reserve0,
        uint256 reserve1,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint256 timestamp
    );
}

/// @title EventEmitter — Central event hub for the v5-ASAMM protocol
/// @notice Called by the Diamond after every major operation. Emits rich events
///         for off-chain indexers and provides query functions for pool data.
/// @dev Only the Diamond (or owner) can emit events. Anyone can query.
contract EventEmitter is IEventEmitter {
    address public immutable diamond;
    address public owner;

    // ──────────────── Pool Registry ────────────────
    bytes32[] public allPoolIds;
    mapping(bytes32 => bool) public isRegistered;
    mapping(bytes32 => PoolInfo) public poolInfos;
    mapping(bytes32 => address[]) internal _poolLPs; // LP addresses per pool
    mapping(bytes32 => mapping(address => bool)) internal _isLP;

    struct PoolInfo {
        address token0;
        address token1;
        address creator;
        uint24 tickSpacing;
        uint256 createdAt;
        uint256 totalSwaps;
        uint256 totalVolume0;
        uint256 totalVolume1;
        uint160 lastSqrtPriceX96;
        uint160 previousSqrtPriceX96;
        int24 lastTick;
    }

    modifier onlyDiamond() {
        require(msg.sender == diamond, "EventEmitter: only diamond");
        _;
    }

    modifier onlyOwnerOrDiamond() {
        require(msg.sender == diamond || msg.sender == owner, "EventEmitter: unauthorized");
        _;
    }

    constructor(address _diamond) {
        diamond = _diamond;
        owner = msg.sender;
    }

    // ═══════════════════════════════════════════════════
    //                  EMIT FUNCTIONS
    // ═══════════════════════════════════════════════════

    function emitPoolCreated(
        bytes32 poolId,
        address creator,
        address token0,
        address token1,
        uint24 tickSpacing,
        IPool.PoolType poolType,
        uint256 baseFee,
        uint256 maxImpactFee
    ) external onlyDiamond {
        if (!isRegistered[poolId]) {
            isRegistered[poolId] = true;
            allPoolIds.push(poolId);
            poolInfos[poolId] = PoolInfo({
                token0: token0,
                token1: token1,
                creator: creator,
                tickSpacing: tickSpacing,
                createdAt: block.timestamp,
                totalSwaps: 0,
                totalVolume0: 0,
                totalVolume1: 0,
                lastSqrtPriceX96: 0,
                previousSqrtPriceX96: 0,
                lastTick: 0
            });
        }

        emit PoolCreatedDetailed(
            poolId,
            creator,
            token0,
            token1,
            tickSpacing,
            poolType,
            baseFee,
            maxImpactFee,
            block.timestamp
        );
    }

    function emitPoolInitialized(bytes32 poolId, uint160 sqrtPriceX96, int24 tick) external onlyDiamond {
        poolInfos[poolId].lastSqrtPriceX96 = sqrtPriceX96;
        poolInfos[poolId].lastTick = tick;

        emit PoolInitializedDetailed(poolId, sqrtPriceX96, tick, block.timestamp);
    }

    function emitSwap(
        bytes32 poolId,
        address sender,
        address recipient,
        bool zeroForOne,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96Before,
        uint160 sqrtPriceX96After,
        int24 tickBefore,
        int24 tickAfter,
        uint128 liquidity,
        uint256 feeAmount
    ) external onlyDiamond {
        PoolInfo storage info = poolInfos[poolId];
        info.previousSqrtPriceX96 = sqrtPriceX96Before;
        info.lastSqrtPriceX96 = sqrtPriceX96After;
        info.lastTick = tickAfter;
        info.totalSwaps++;
        if (amount0 > 0) info.totalVolume0 += uint256(amount0);
        if (amount1 > 0) info.totalVolume1 += uint256(amount1);

        emit SwapExecuted(
            poolId,
            sender,
            recipient,
            zeroForOne,
            amount0,
            amount1,
            sqrtPriceX96Before,
            sqrtPriceX96After,
            tickBefore,
            tickAfter,
            liquidity,
            feeAmount,
            block.timestamp
        );
    }

    function emitLiquidityAdded(
        bytes32 poolId,
        address provider,
        uint256 positionId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1,
        uint256 reserve0After,
        uint256 reserve1After,
        uint128 totalLiquidityAfter
    ) external onlyDiamond {
        // Track LP addresses
        if (!_isLP[poolId][provider]) {
            _isLP[poolId][provider] = true;
            _poolLPs[poolId].push(provider);
        }

        emit LiquidityAddedDetailed(
            poolId,
            provider,
            positionId,
            tickLower,
            tickUpper,
            liquidity,
            amount0,
            amount1,
            reserve0After,
            reserve1After,
            totalLiquidityAfter,
            block.timestamp
        );
    }

    function emitLiquidityRemoved(
        bytes32 poolId,
        address provider,
        uint256 positionId,
        uint128 liquidityRemoved,
        uint256 amount0,
        uint256 amount1,
        uint256 reserve0After,
        uint256 reserve1After,
        uint128 totalLiquidityAfter
    ) external onlyDiamond {
        emit LiquidityRemovedDetailed(
            poolId,
            provider,
            positionId,
            liquidityRemoved,
            amount0,
            amount1,
            reserve0After,
            reserve1After,
            totalLiquidityAfter,
            block.timestamp
        );
    }

    function emitFeesCollected(
        bytes32 poolId,
        address collector,
        uint256 amount0,
        uint256 amount1,
        uint256 protocolFees0Remaining,
        uint256 protocolFees1Remaining
    ) external onlyDiamond {
        emit FeesCollectedDetailed(
            poolId,
            collector,
            amount0,
            amount1,
            protocolFees0Remaining,
            protocolFees1Remaining,
            block.timestamp
        );
    }

    function emitPoolSnapshot(
        bytes32 poolId,
        uint160 sqrtPriceX96,
        int24 currentTick,
        uint128 liquidity,
        uint256 reserve0,
        uint256 reserve1,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) external onlyDiamond {
        emit PoolSnapshot(
            poolId,
            sqrtPriceX96,
            currentTick,
            liquidity,
            reserve0,
            reserve1,
            feeGrowthGlobal0X128,
            feeGrowthGlobal1X128,
            block.timestamp
        );
    }

    // ═══════════════════════════════════════════════════
    //               QUERY FUNCTIONS
    // ═══════════════════════════════════════════════════

    /// @notice Get the total number of registered pools
    function getPoolCount() external view returns (uint256) {
        return allPoolIds.length;
    }

    /// @notice Get all registered pool IDs
    function getAllPoolIds() external view returns (bytes32[] memory) {
        return allPoolIds;
    }

    /// @notice Get full pool info
    function getPoolInfo(bytes32 poolId) external view returns (PoolInfo memory) {
        return poolInfos[poolId];
    }

    /// @notice Get all LP addresses for a pool
    function getPoolLPs(bytes32 poolId) external view returns (address[] memory) {
        return _poolLPs[poolId];
    }

    /// @notice Get LP count for a pool
    function getPoolLPCount(bytes32 poolId) external view returns (uint256) {
        return _poolLPs[poolId].length;
    }

    /// @notice Check if address is an LP for a pool
    function isPoolLP(bytes32 poolId, address addr) external view returns (bool) {
        return _isLP[poolId][addr];
    }

    /// @notice Get pool reserves (queries Diamond directly)
    function getReserves(bytes32 poolId) external view returns (uint256 reserve0, uint256 reserve1) {
        IPool.PoolState memory state = IPoolReader(diamond).getPoolState(poolId);
        return (state.reserve0, state.reserve1);
    }

    /// @notice Get current price as sqrtPriceX96 and tick
    function getPrice(bytes32 poolId) external view returns (uint160 sqrtPriceX96, int24 tick) {
        IPool.PoolState memory state = IPoolReader(diamond).getPoolState(poolId);
        return (state.sqrtPriceX96, state.currentTick);
    }

    /// @notice Get price change since last swap (cached values)
    function getPriceChange(
        bytes32 poolId
    ) external view returns (uint160 currentPrice, uint160 previousPrice, int256 priceChangeBps) {
        PoolInfo memory info = poolInfos[poolId];
        currentPrice = info.lastSqrtPriceX96;
        previousPrice = info.previousSqrtPriceX96;

        if (previousPrice > 0 && currentPrice > 0) {
            if (currentPrice >= previousPrice) {
                priceChangeBps = int256((uint256(currentPrice - previousPrice) * 10000) / uint256(previousPrice));
            } else {
                priceChangeBps = -int256((uint256(previousPrice - currentPrice) * 10000) / uint256(previousPrice));
            }
        }
    }

    /// @notice Get pool stats summary
    function getPoolStats(
        bytes32 poolId
    )
        external
        view
        returns (
            uint256 totalSwaps,
            uint256 totalVolume0,
            uint256 totalVolume1,
            uint256 lpCount,
            uint256 createdAt,
            address creator
        )
    {
        PoolInfo memory info = poolInfos[poolId];
        return (
            info.totalSwaps,
            info.totalVolume0,
            info.totalVolume1,
            _poolLPs[poolId].length,
            info.createdAt,
            info.creator
        );
    }

    /// @notice Get multiple pool stats in one call (for dashboards)
    function getMultiPoolStats(
        bytes32[] calldata poolIds
    )
        external
        view
        returns (
            uint256[] memory swapCounts,
            uint256[] memory volumes0,
            uint256[] memory volumes1,
            uint160[] memory prices
        )
    {
        uint256 len = poolIds.length;
        swapCounts = new uint256[](len);
        volumes0 = new uint256[](len);
        volumes1 = new uint256[](len);
        prices = new uint160[](len);

        for (uint256 i = 0; i < len; i++) {
            PoolInfo memory info = poolInfos[poolIds[i]];
            swapCounts[i] = info.totalSwaps;
            volumes0[i] = info.totalVolume0;
            volumes1[i] = info.totalVolume1;
            prices[i] = info.lastSqrtPriceX96;
        }
    }
}

/// @dev Minimal interface to read pool state from the Diamond
interface IPoolReader {
    function getPoolState(bytes32 poolId) external view returns (IPool.PoolState memory);
}
