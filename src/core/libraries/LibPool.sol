// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../storage/AppStorage.sol";
import "../interfaces/IPool.sol";

/// @title LibPool — Pool state management and pool ID computation
/// @notice Reads and writes pool state within AppStorage
/// @dev Custom implementation — no external dependencies
library LibPool {
    error PoolAlreadyExists();
    error PoolDoesNotExist();
    error PoolNotInitialized();
    error InvalidTokenOrder();
    error InvalidTickSpacing();
    error IdenticalTokens();
    error ZeroAddress();

    /// @notice Compute the deterministic pool ID from token pair and tick spacing
    /// @dev Tokens are sorted so poolId is order-independent
    function computePoolId(address token0, address token1, uint24 tickSpacing) internal pure returns (bytes32) {
        (address t0, address t1) = sortTokens(token0, token1);
        return keccak256(abi.encodePacked(t0, t1, tickSpacing));
    }

    /// @notice Sort two token addresses
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) revert IdenticalTokens();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /// @notice Get pool config from storage
    function getPoolConfig(bytes32 poolId) internal view returns (IPool.PoolConfig storage) {
        AppStorage storage s = LibAppStorage.appStorage();
        if (s.poolConfigs[poolId].token0 == address(0)) revert PoolDoesNotExist();
        return s.poolConfigs[poolId];
    }

    /// @notice Get pool state from storage
    function getPoolState(bytes32 poolId) internal view returns (IPool.PoolState storage) {
        AppStorage storage s = LibAppStorage.appStorage();
        if (!s.poolStates[poolId].initialized) revert PoolNotInitialized();
        return s.poolStates[poolId];
    }

    /// @notice Check if a pool exists
    function poolExists(bytes32 poolId) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.poolConfigs[poolId].token0 != address(0);
    }

    /// @notice Create a new pool (does not initialize it)
    function createPool(IPool.PoolConfig memory config) internal returns (bytes32 poolId) {
        AppStorage storage s = LibAppStorage.appStorage();

        (config.token0, config.token1) = sortTokens(config.token0, config.token1);
        if (config.tickSpacing == 0) revert InvalidTickSpacing();

        poolId = computePoolId(config.token0, config.token1, config.tickSpacing);
        if (s.poolConfigs[poolId].token0 != address(0)) revert PoolAlreadyExists();

        s.poolConfigs[poolId] = config;
        s.poolIds.push(poolId);
        s.poolCount++;

        return poolId;
    }

    /// @notice Initialize a pool with a starting price
    function initializePool(bytes32 poolId, uint160 sqrtPriceX96, int24 tick) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        if (s.poolConfigs[poolId].token0 == address(0)) revert PoolDoesNotExist();

        IPool.PoolState storage state = s.poolStates[poolId];
        require(!state.initialized, "LibPool: already initialized");

        state.sqrtPriceX96 = sqrtPriceX96;
        state.currentTick = tick;
        state.lastObservationTimestamp = uint32(block.timestamp);
        state.initialized = true;
    }

    /// @notice Update reserves after a swap or liquidity change
    function updateReserves(bytes32 poolId, uint256 reserve0, uint256 reserve1) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        s.poolStates[poolId].reserve0 = reserve0;
        s.poolStates[poolId].reserve1 = reserve1;
    }

    /// @notice Update the pool's current price and tick
    function updatePrice(bytes32 poolId, uint160 sqrtPriceX96, int24 tick) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        s.poolStates[poolId].sqrtPriceX96 = sqrtPriceX96;
        s.poolStates[poolId].currentTick = tick;
    }

    /// @notice Update the pool's liquidity
    function updateLiquidity(bytes32 poolId, uint128 liquidity) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        s.poolStates[poolId].liquidity = liquidity;
    }
}
