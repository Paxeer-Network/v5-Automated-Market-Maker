// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../interfaces/IPool.sol";
import "../interfaces/IFeeFacet.sol";
import "../libraries/LibPool.sol";
import "../libraries/LibFee.sol";
import "../libraries/LibOracle.sol";
import "../libraries/LibSecurity.sol";
import "../libraries/LibDiamond.sol";
import "../libraries/LibEventEmitter.sol";
import "../storage/AppStorage.sol";
import "../../utils/TickMath.sol";

/// @title PoolFacet — Pool creation and management
/// @notice Allows creating and initializing pools with configurable sigmoid parameters
/// @dev Diamond facet — operates on AppStorage via delegatecall
contract PoolFacet is IPool {
    /// @notice Create a new pool — permissionless (anyone can create)
    /// @param config The pool configuration
    /// @return poolId The deterministic pool identifier
    function createPool(PoolConfig calldata config) external returns (bytes32 poolId) {
        LibSecurity.requireNotPaused();

        // Validate tick spacing within allowed range
        require(config.tickSpacing > 0 && config.tickSpacing <= 16384, "PoolFacet: invalid tick spacing");
        // Validate fee bounds
        require(config.baseFee <= 10000, "PoolFacet: baseFee > 100%");
        require(config.maxImpactFee <= 10000, "PoolFacet: maxImpactFee > 100%");

        poolId = LibPool.createPool(config);

        // Set default fee config
        AppStorage storage s = LibAppStorage.appStorage();
        s.feeConfigs[poolId] = LibFee.defaultFeeConfig();

        // Track pool creator
        s.poolCreators[poolId] = msg.sender;

        emit PoolCreated(poolId, config.token0, config.token1, config.poolType, config.tickSpacing);

        // Notify EventEmitter
        LibEventEmitter.emitPoolCreated(
            poolId, msg.sender, config.token0, config.token1,
            config.tickSpacing, config.poolType, config.baseFee, config.maxImpactFee
        );
    }

    /// @notice Initialize a pool with a starting price
    /// @param poolId The pool to initialize
    /// @param sqrtPriceX96 The initial sqrt price (Q64.96)
    function initializePool(bytes32 poolId, uint160 sqrtPriceX96) external {
        LibSecurity.requireNotPaused();

        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);
        LibPool.initializePool(poolId, sqrtPriceX96, tick);

        // Initialize the oracle for this pool
        LibOracle.initialize(poolId, tick);

        emit PoolInitialized(poolId, sqrtPriceX96, tick);

        LibEventEmitter.emitPoolInitialized(poolId, sqrtPriceX96, tick);
    }

    /// @notice Get pool configuration
    function getPoolConfig(bytes32 poolId) external view returns (PoolConfig memory) {
        return LibPool.getPoolConfig(poolId);
    }

    /// @notice Get pool state
    function getPoolState(bytes32 poolId) external view returns (PoolState memory) {
        return LibPool.getPoolState(poolId);
    }

    /// @notice Check if a pool exists
    function poolExists(bytes32 poolId) external view returns (bool) {
        return LibPool.poolExists(poolId);
    }

    /// @notice Compute a pool ID from parameters
    function computePoolId(
        address token0,
        address token1,
        uint24 tickSpacing
    ) external pure returns (bytes32) {
        return LibPool.computePoolId(token0, token1, tickSpacing);
    }

    /// @notice Get count of all pools
    function getPoolCount() external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.poolCount;
    }

    /// @notice Get all pool IDs
    function getAllPoolIds() external view returns (bytes32[] memory) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.poolIds;
    }

    /// @notice Pause the protocol (owner or pause guardian only)
    function pause() external {
        LibSecurity.requirePauseGuardian();
        LibSecurity.pause();
    }

    /// @notice Unpause the protocol (owner only)
    function unpause() external {
        LibSecurity.requireOwner();
        LibSecurity.unpause();
    }

    /// @notice Set pause guardian (owner only)
    function setPauseGuardian(address guardian, bool enabled) external {
        LibSecurity.requireOwner();
        if (enabled) {
            LibSecurity.addPauseGuardian(guardian);
        } else {
            LibSecurity.removePauseGuardian(guardian);
        }
    }

    /// @notice Set the protocol treasury address (owner only)
    function setTreasury(address treasury) external {
        LibSecurity.requireOwner();
        require(treasury != address(0), "PoolFacet: zero address");
        AppStorage storage s = LibAppStorage.appStorage();
        s.treasury = treasury;
    }

    /// @notice Set the EventEmitter contract address (owner only)
    function setEventEmitter(address emitter) external {
        LibSecurity.requireOwner();
        AppStorage storage s = LibAppStorage.appStorage();
        s.eventEmitter = emitter;
    }

    /// @notice Get the pool creator address
    function getPoolCreator(bytes32 poolId) external view returns (address) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.poolCreators[poolId];
    }
}
