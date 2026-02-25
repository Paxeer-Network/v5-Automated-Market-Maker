// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../storage/AppStorage.sol";
import "../EventEmitter.sol";
import "../interfaces/IPool.sol";

/// @title LibEventEmitter — Helper for calling the EventEmitter from facets
/// @notice All calls are fire-and-forget — if EventEmitter is not set, calls are silently skipped
library LibEventEmitter {
    function _emitter() private view returns (address) {
        return LibAppStorage.appStorage().eventEmitter;
    }

    function emitPoolCreated(
        bytes32 poolId,
        address creator,
        address token0,
        address token1,
        uint24 tickSpacing,
        IPool.PoolType poolType,
        uint256 baseFee,
        uint256 maxImpactFee
    ) internal {
        address emitter = _emitter();
        if (emitter == address(0)) return;
        EventEmitter(emitter).emitPoolCreated(
            poolId,
            creator,
            token0,
            token1,
            tickSpacing,
            poolType,
            baseFee,
            maxImpactFee
        );
    }

    function emitPoolInitialized(bytes32 poolId, uint160 sqrtPriceX96, int24 tick) internal {
        address emitter = _emitter();
        if (emitter == address(0)) return;
        EventEmitter(emitter).emitPoolInitialized(poolId, sqrtPriceX96, tick);
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
    ) internal {
        address emitter = _emitter();
        if (emitter == address(0)) return;
        EventEmitter(emitter).emitSwap(
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
            feeAmount
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
    ) internal {
        address emitter = _emitter();
        if (emitter == address(0)) return;
        EventEmitter(emitter).emitLiquidityAdded(
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
            totalLiquidityAfter
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
    ) internal {
        address emitter = _emitter();
        if (emitter == address(0)) return;
        EventEmitter(emitter).emitLiquidityRemoved(
            poolId,
            provider,
            positionId,
            liquidityRemoved,
            amount0,
            amount1,
            reserve0After,
            reserve1After,
            totalLiquidityAfter
        );
    }

    function emitFeesCollected(
        bytes32 poolId,
        address collector,
        uint256 amount0,
        uint256 amount1,
        uint256 protocolFees0Remaining,
        uint256 protocolFees1Remaining
    ) internal {
        address emitter = _emitter();
        if (emitter == address(0)) return;
        EventEmitter(emitter).emitFeesCollected(
            poolId,
            collector,
            amount0,
            amount1,
            protocolFees0Remaining,
            protocolFees1Remaining
        );
    }
}
