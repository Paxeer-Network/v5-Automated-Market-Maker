// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../interfaces/IOraclePegFacet.sol";
import "../interfaces/IASAMMOracle.sol";
import "../interfaces/IPool.sol";
import "../libraries/LibSecurity.sol";
import "../libraries/LibDiamond.sol";
import "../storage/AppStorage.sol";
import "../../utils/FullMath.sol";

/// @title OraclePegFacet — External oracle connection for pegged/wrapped asset pools
/// @notice Anchors pool mid-price to an external oracle feed (TWAP + spot)
/// @dev Diamond facet — operates on AppStorage via delegatecall
contract OraclePegFacet is IOraclePegFacet {
    uint256 internal constant Q128 = 1 << 128;
    uint256 internal constant PRICE_DECIMALS = 1e18;

    /// @inheritdoc IOraclePegFacet
    function setOraclePeg(bytes32 poolId, PegConfig calldata config) external {
        LibSecurity.requireOwner();

        AppStorage storage s = LibAppStorage.appStorage();
        require(s.poolConfigs[poolId].token0 != address(0), "OraclePegFacet: pool does not exist");
        require(config.oracleAddress != address(0), "OraclePegFacet: zero oracle address");
        require(config.twapPeriod > 0, "OraclePegFacet: zero twap period");
        require(config.maxStaleness > 0, "OraclePegFacet: zero staleness");
        require(config.maxSpotDeviation > 0 && config.maxSpotDeviation <= 5000, "OraclePegFacet: invalid deviation");

        // Verify oracle is callable
        IASAMMOracle oracle = IASAMMOracle(config.oracleAddress);
        (uint256 spot, uint256 updatedAt) = oracle.spotPrice();
        require(spot > 0, "OraclePegFacet: oracle returned zero");
        require(updatedAt > 0, "OraclePegFacet: oracle not initialized");

        s.pegConfigs[poolId] = config;
        s.isPeggedPool[poolId] = true;

        // Update pool type
        s.poolConfigs[poolId].poolType = IPool.PoolType.OraclePegged;

        emit OraclePegSet(poolId, config.oracleAddress, config.twapPeriod, config.maxStaleness);
    }

    /// @inheritdoc IOraclePegFacet
    function removeOraclePeg(bytes32 poolId) external {
        LibSecurity.requireOwner();

        AppStorage storage s = LibAppStorage.appStorage();
        require(s.isPeggedPool[poolId], "OraclePegFacet: not a pegged pool");

        delete s.pegConfigs[poolId];
        s.isPeggedPool[poolId] = false;
        s.poolConfigs[poolId].poolType = IPool.PoolType.Standard;

        emit OraclePegRemoved(poolId);
    }

    /// @inheritdoc IOraclePegFacet
    function getOracleMidPrice(bytes32 poolId) external view returns (uint256 midPrice, bool isValid) {
        AppStorage storage s = LibAppStorage.appStorage();
        require(s.isPeggedPool[poolId], "OraclePegFacet: not a pegged pool");

        PegConfig storage config = s.pegConfigs[poolId];
        IASAMMOracle oracle = IASAMMOracle(config.oracleAddress);

        // Get TWAP (primary anchor)
        uint256 twap = oracle.twapPrice(config.twapPeriod);

        // Get spot for sanity check
        (uint256 spot, uint256 updatedAt) = oracle.spotPrice();

        // Check staleness
        if (block.timestamp - updatedAt > config.maxStaleness) {
            return (0, false);
        }

        // Check spot/TWAP deviation
        uint256 deviation;
        if (spot > twap) {
            deviation = FullMath.mulDiv(spot - twap, 10_000, twap);
        } else {
            deviation = FullMath.mulDiv(twap - spot, 10_000, twap);
        }

        if (deviation > config.maxSpotDeviation) {
            return (0, false);
        }

        // Convert TWAP to Q128.128 (assuming 18 decimal oracle price)
        midPrice = FullMath.mulDiv(twap, Q128, PRICE_DECIMALS);
        isValid = true;
    }

    /// @inheritdoc IOraclePegFacet
    function getPegConfig(bytes32 poolId) external view returns (PegConfig memory) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.pegConfigs[poolId];
    }

    /// @notice Check if a pool is oracle-pegged
    function isPoolPegged(bytes32 poolId) external view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.isPeggedPool[poolId];
    }

    /// @notice Get raw oracle prices for debugging/monitoring
    function getRawOraclePrices(bytes32 poolId) external view returns (
        uint256 spotPrice_,
        uint256 spotUpdatedAt,
        uint256 twapPrice_
    ) {
        AppStorage storage s = LibAppStorage.appStorage();
        require(s.isPeggedPool[poolId], "OraclePegFacet: not pegged");

        PegConfig storage config = s.pegConfigs[poolId];
        IASAMMOracle oracle = IASAMMOracle(config.oracleAddress);

        (spotPrice_, spotUpdatedAt) = oracle.spotPrice();
        twapPrice_ = oracle.twapPrice(config.twapPeriod);
    }
}
