// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../interfaces/ISwapFacet.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IASAMMOracle.sol";
import "../interfaces/IOrderFacet.sol";
import "../libraries/LibPool.sol";
import "../libraries/LibSwap.sol";
import "../libraries/LibFee.sol";
import "../libraries/LibOracle.sol";
import "../libraries/LibSecurity.sol";
import "../libraries/LibTransfer.sol";
import "../libraries/LibTickBitmap.sol";
import "../libraries/LibEventEmitter.sol";
import "../storage/AppStorage.sol";
import "../../utils/FullMath.sol";
import "../../utils/SqrtPriceMath.sol";
import "../../utils/TickMath.sol";

/// @title SwapFacet — Sigmoid bonding curve swap execution with tick iteration
/// @notice Executes swaps by stepping through initialized ticks, applying sigmoid-adjusted
///         fees per step, crossing ticks (updating liquidity), and executing inline limit orders.
/// @dev Diamond facet — operates on AppStorage via delegatecall
contract SwapFacet is ISwapFacet {
    uint256 internal constant Q128 = 1 << 128;
    uint256 internal constant MAX_SWAP_LOOP = 500; // Safety cap on tick iterations

    /// @inheritdoc ISwapFacet
    function swap(SwapParams calldata params) external returns (SwapResult memory result) {
        LibSecurity.nonReentrantBefore();
        LibSecurity.requireNotPaused();
        LibSecurity.checkDeadline(params.deadline);

        AppStorage storage s = LibAppStorage.appStorage();
        IPool.PoolConfig storage config = s.poolConfigs[params.poolId];
        IPool.PoolState storage state = s.poolStates[params.poolId];

        require(state.initialized, "SwapFacet: pool not initialized");
        require(params.amountSpecified != 0, "SwapFacet: zero amount");

        bool exactInput = params.amountSpecified > 0;

        // Determine price limit
        uint160 sqrtPriceLimitX96 = params.sqrtPriceLimitX96;
        if (sqrtPriceLimitX96 == 0) {
            sqrtPriceLimitX96 = params.zeroForOne
                ? TickMath.MIN_SQRT_PRICE + 1
                : TickMath.MAX_SQRT_PRICE - 1;
        }

        // Validate price limit direction
        if (params.zeroForOne) {
            require(sqrtPriceLimitX96 < state.sqrtPriceX96, "SwapFacet: SPL");
            require(sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE, "SwapFacet: SPL min");
        } else {
            require(sqrtPriceLimitX96 > state.sqrtPriceX96, "SwapFacet: SPL");
            require(sqrtPriceLimitX96 < TickMath.MAX_SQRT_PRICE, "SwapFacet: SPL max");
        }

        // Check if this is an oracle-pegged pool (uses simplified path)
        bool isPegged = s.isPeggedPool[params.poolId];

        // ─── Initialize swap state ───
        LibSwap.SwapState memory swapState = LibSwap.SwapState({
            amountSpecifiedRemaining: params.amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: state.sqrtPriceX96,
            tick: state.currentTick,
            liquidity: state.liquidity,
            feeGrowthGlobalX128: params.zeroForOne
                ? state.feeGrowthGlobal0X128
                : state.feeGrowthGlobal1X128,
            totalFees: 0
        });

        // ─── Tick iteration loop ───
        for (uint256 iter = 0; iter < MAX_SWAP_LOOP; iter++) {
            if (swapState.amountSpecifiedRemaining == 0) break;

            LibSwap.StepComputations memory step;
            step.sqrtPriceStartX96 = swapState.sqrtPriceX96;

            // Find the next initialized tick in the swap direction
            (step.tickNext, step.initialized) = LibTickBitmap.nextInitializedTickWithinOneWord(
                params.poolId,
                swapState.tick,
                params.zeroForOne // lte = true for zeroForOne (price decreasing)
            );

            // Clamp tickNext to min/max
            if (step.tickNext < TickMath.MIN_TICK) step.tickNext = TickMath.MIN_TICK;
            if (step.tickNext > TickMath.MAX_TICK) step.tickNext = TickMath.MAX_TICK;

            // Get the sqrt price at the next tick
            step.sqrtPriceNextX96 = TickMath.getSqrtPriceAtTick(step.tickNext);

            // Determine the target price for this step (bounded by price limit)
            uint160 sqrtPriceTargetX96;
            if (params.zeroForOne) {
                sqrtPriceTargetX96 = step.sqrtPriceNextX96 < sqrtPriceLimitX96
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96;
            } else {
                sqrtPriceTargetX96 = step.sqrtPriceNextX96 > sqrtPriceLimitX96
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96;
            }

            // Compute amounts for this step using Uniswap V3-style math,
            // then apply sigmoid adjustment on top
            _computeSwapStep(
                swapState,
                step,
                sqrtPriceTargetX96,
                params.poolId,
                params.zeroForOne,
                exactInput,
                isPegged,
                config
            );

            // Accumulate fee growth
            if (swapState.liquidity > 0 && step.feeAmount > 0) {
                swapState.feeGrowthGlobalX128 += FullMath.mulDiv(
                    step.feeAmount, Q128, swapState.liquidity
                );
            }
            swapState.totalFees += step.feeAmount;

            // Check if we've reached the next tick boundary
            if (swapState.sqrtPriceX96 == step.sqrtPriceNextX96) {
                if (step.initialized) {
                    // Cross the tick: update liquidity from tick's liquidityNet
                    TickInfo storage tickData = s.ticks[params.poolId][step.tickNext];

                    // Update fee growth outside for the crossed tick
                    tickData.feeGrowthOutside0X128 = state.feeGrowthGlobal0X128 - tickData.feeGrowthOutside0X128;
                    tickData.feeGrowthOutside1X128 = state.feeGrowthGlobal1X128 - tickData.feeGrowthOutside1X128;

                    int128 liquidityNet = tickData.liquidityNet;
                    // When moving left (zeroForOne), negate liquidityNet
                    if (params.zeroForOne) liquidityNet = -liquidityNet;

                    swapState.liquidity = liquidityNet >= 0
                        ? swapState.liquidity + uint128(liquidityNet)
                        : swapState.liquidity - uint128(-liquidityNet);

                    // ─── Inline limit order execution ───
                    _executeOrdersAtTick(s, params.poolId, step.tickNext, params.zeroForOne);
                }

                // Update tick for next iteration
                swapState.tick = params.zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else {
                // Price didn't reach the next tick — swap is done within this range
                swapState.tick = TickMath.getTickAtSqrtPrice(swapState.sqrtPriceX96);
            }

            // If price limit reached, stop
            if (swapState.sqrtPriceX96 == sqrtPriceLimitX96) break;
        }

        // ─── Finalize ───
        address tokenIn = params.zeroForOne ? config.token0 : config.token1;
        address tokenOut = params.zeroForOne ? config.token1 : config.token0;

        // Compute final amounts
        int256 amount0;
        int256 amount1;
        if (exactInput) {
            amount0 = params.zeroForOne
                ? params.amountSpecified - swapState.amountSpecifiedRemaining
                : swapState.amountCalculated;
            amount1 = params.zeroForOne
                ? swapState.amountCalculated
                : params.amountSpecified - swapState.amountSpecifiedRemaining;
        } else {
            amount0 = params.zeroForOne
                ? swapState.amountCalculated
                : params.amountSpecified - swapState.amountSpecifiedRemaining;
            amount1 = params.zeroForOne
                ? params.amountSpecified - swapState.amountSpecifiedRemaining
                : swapState.amountCalculated;
        }

        // Update pool state
        state.sqrtPriceX96 = swapState.sqrtPriceX96;
        state.currentTick = swapState.tick;
        state.liquidity = swapState.liquidity;

        // Update fee growth globals
        if (params.zeroForOne) {
            state.feeGrowthGlobal0X128 = swapState.feeGrowthGlobalX128;
        } else {
            state.feeGrowthGlobal1X128 = swapState.feeGrowthGlobalX128;
        }

        // Transfer tokens
        uint256 amountInAbs = amount0 > 0 ? uint256(amount0) : uint256(amount1);
        uint256 amountOutAbs = amount0 < 0 ? uint256(-amount0) : uint256(-amount1);

        LibTransfer.pullToken(tokenIn, msg.sender, amountInAbs);
        LibTransfer.pushToken(tokenOut, params.recipient, amountOutAbs);

        // Distribute fees
        _distributeFees(params.poolId, tokenIn, swapState.totalFees);

        // Update reserves
        if (params.zeroForOne) {
            state.reserve0 += amountInAbs;
            state.reserve1 -= amountOutAbs;
        } else {
            state.reserve1 += amountInAbs;
            state.reserve0 -= amountOutAbs;
        }

        // Update oracle observation
        LibOracle.write(params.poolId, swapState.tick, swapState.liquidity);

        // Record trader activity for rebate tracking
        _recordTraderActivity(params.poolId, msg.sender, amountInAbs);

        // Build result
        result = SwapResult({
            amount0: amount0,
            amount1: amount1,
            sqrtPriceX96After: swapState.sqrtPriceX96,
            tickAfter: swapState.tick,
            liquidityAfter: swapState.liquidity,
            feeAmount: swapState.totalFees
        });

        emit Swap(
            params.poolId,
            msg.sender,
            params.recipient,
            amount0,
            amount1,
            swapState.sqrtPriceX96,
            swapState.liquidity,
            swapState.tick,
            swapState.totalFees
        );

        // Notify EventEmitter with before/after state
        LibEventEmitter.emitSwap(
            params.poolId,
            msg.sender,
            params.recipient,
            params.zeroForOne,
            amount0,
            amount1,
            state.sqrtPriceX96,  // already updated — use result
            swapState.sqrtPriceX96,
            state.currentTick,
            swapState.tick,
            swapState.liquidity,
            swapState.totalFees
        );

        LibSecurity.nonReentrantAfter();
    }

    /// @dev Compute a single swap step: amounts in/out, fee, new price
    function _computeSwapStep(
        LibSwap.SwapState memory swapState,
        LibSwap.StepComputations memory step,
        uint160 sqrtPriceTargetX96,
        bytes32 poolId,
        bool zeroForOne,
        bool exactInput,
        bool isPegged,
        IPool.PoolConfig storage config
    ) internal view {
        AppStorage storage s = LibAppStorage.appStorage();

        uint256 amountSpecifiedAbs = swapState.amountSpecifiedRemaining > 0
            ? uint256(swapState.amountSpecifiedRemaining)
            : uint256(-swapState.amountSpecifiedRemaining);

        // Compute progressive fee for this step
        uint256 feeBps = LibFee.calculateProgressiveFee(
            s.feeConfigs[poolId].baseFee,
            s.feeConfigs[poolId].maxImpactFee,
            amountSpecifiedAbs,
            uint256(swapState.liquidity)
        );

        if (exactInput) {
            // Compute how much of the remaining input can fill this price range
            uint256 amountInMax = zeroForOne
                ? SqrtPriceMath.getAmount0Delta(sqrtPriceTargetX96, step.sqrtPriceStartX96, swapState.liquidity, true)
                : SqrtPriceMath.getAmount1Delta(step.sqrtPriceStartX96, sqrtPriceTargetX96, swapState.liquidity, true);

            // Apply fee to determine usable input
            (uint256 amountInAfterFee,) = LibFee.applyFee(amountSpecifiedAbs, feeBps);

            if (amountInAfterFee >= amountInMax) {
                // Fills the entire range to the target tick
                step.amountIn = amountInMax;
                swapState.sqrtPriceX96 = sqrtPriceTargetX96;
            } else {
                // Partially fills — compute new price
                step.amountIn = amountInAfterFee;
                swapState.sqrtPriceX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
                    step.sqrtPriceStartX96, swapState.liquidity, amountInAfterFee, zeroForOne
                );
            }

            // Compute output for this step
            step.amountOut = zeroForOne
                ? SqrtPriceMath.getAmount1Delta(swapState.sqrtPriceX96, step.sqrtPriceStartX96, swapState.liquidity, false)
                : SqrtPriceMath.getAmount0Delta(step.sqrtPriceStartX96, swapState.sqrtPriceX96, swapState.liquidity, false);

            // Apply sigmoid reduction to output if pool uses sigmoid curve
            if (!isPegged && config.sigmoidK > 0 && swapState.liquidity > 0) {
                uint256 xOverL = FullMath.mulDiv(step.amountIn, Q128, uint256(swapState.liquidity));
                uint256 alphaXOverL = FixedPointMath.mulQ128(config.sigmoidAlpha, xOverL);
                uint256 tanhVal = FixedPointMath.tanh(alphaXOverL);
                uint256 impact = FixedPointMath.mulQ128(config.sigmoidK, tanhVal);
                if (impact < Q128) {
                    step.amountOut = FullMath.mulDiv(step.amountOut, Q128 - impact, Q128);
                } else {
                    step.amountOut = step.amountOut / 100;
                }
            }

            // Compute fee for this step
            step.feeAmount = FullMath.mulDiv(step.amountIn, feeBps, 10_000);
            uint256 totalConsumed = step.amountIn + step.feeAmount;

            swapState.amountSpecifiedRemaining -= int256(totalConsumed);
            swapState.amountCalculated -= int256(step.amountOut);
        } else {
            // Exact output path
            uint256 amountOutMax = zeroForOne
                ? SqrtPriceMath.getAmount1Delta(sqrtPriceTargetX96, step.sqrtPriceStartX96, swapState.liquidity, false)
                : SqrtPriceMath.getAmount0Delta(step.sqrtPriceStartX96, sqrtPriceTargetX96, swapState.liquidity, false);

            if (amountSpecifiedAbs >= amountOutMax) {
                step.amountOut = amountOutMax;
                swapState.sqrtPriceX96 = sqrtPriceTargetX96;
            } else {
                step.amountOut = amountSpecifiedAbs;
                swapState.sqrtPriceX96 = SqrtPriceMath.getNextSqrtPriceFromOutput(
                    step.sqrtPriceStartX96, swapState.liquidity, amountSpecifiedAbs, zeroForOne
                );
            }

            step.amountIn = zeroForOne
                ? SqrtPriceMath.getAmount0Delta(swapState.sqrtPriceX96, step.sqrtPriceStartX96, swapState.liquidity, true)
                : SqrtPriceMath.getAmount1Delta(step.sqrtPriceStartX96, swapState.sqrtPriceX96, swapState.liquidity, true);

            step.feeAmount = FullMath.mulDiv(step.amountIn, feeBps, 10_000);

            swapState.amountSpecifiedRemaining += int256(step.amountOut);
            swapState.amountCalculated += int256(step.amountIn + step.feeAmount);
        }
    }

    /// @dev Execute pending limit orders at a crossed tick
    function _executeOrdersAtTick(
        AppStorage storage s,
        bytes32 poolId,
        int24 tick,
        bool zeroForOne
    ) internal {
        OrderBucket storage bucket = s.orderBuckets[poolId][tick];
        uint256 head = bucket.headIndex;
        uint256 len = bucket.orderIds.length;

        // Process orders in FIFO order
        for (uint256 i = head; i < len; i++) {
            uint256 orderId = bucket.orderIds[i];
            IOrderFacet.Order storage order = s.orders[orderId];

            // Skip cancelled, executed, or expired orders
            if (order.status != IOrderFacet.OrderStatus.Active) continue;
            if (order.expiry > 0 && block.timestamp > order.expiry) {
                order.status = IOrderFacet.OrderStatus.Expired;
                if (s.activeOrderCounts[poolId] > 0) s.activeOrderCounts[poolId]--;
                continue;
            }

            // Only execute orders that match the swap direction
            // For a zeroForOne swap (price moving down), execute limit sells (zeroForOne = true)
            if (order.zeroForOne != zeroForOne) continue;

            // Mark as filled
            order.status = IOrderFacet.OrderStatus.Filled;
            order.amountFilled = order.amountTotal;
            if (s.activeOrderCounts[poolId] > 0) s.activeOrderCounts[poolId]--;

            bucket.headIndex = i + 1;
        }
    }

    /// @dev Get oracle mid-price for a pegged pool
    function _getOracleMidPrice(bytes32 poolId) internal view returns (uint256 midPrice, bool isValid) {
        AppStorage storage s = LibAppStorage.appStorage();
        IOraclePegFacet.PegConfig storage pegConfig = s.pegConfigs[poolId];

        IASAMMOracle oracle = IASAMMOracle(pegConfig.oracleAddress);

        // Get TWAP as primary anchor
        uint256 twap = oracle.twapPrice(pegConfig.twapPeriod);

        // Get spot for sanity check
        (uint256 spot, uint256 updatedAt) = oracle.spotPrice();

        // Check staleness
        if (block.timestamp - updatedAt > pegConfig.maxStaleness) {
            return (0, false);
        }

        // Check spot/TWAP deviation
        uint256 deviation;
        if (spot > twap) {
            deviation = FullMath.mulDiv(spot - twap, 10_000, twap);
        } else {
            deviation = FullMath.mulDiv(twap - spot, 10_000, twap);
        }

        if (deviation > pegConfig.maxSpotDeviation) {
            return (0, false);
        }

        // Use TWAP as mid-price (convert to Q128.128)
        midPrice = FullMath.mulDiv(twap, Q128, 1e18);
        isValid = true;
    }

    /// @dev Distribute fees between LP, protocol, and trader rebate pool
    function _distributeFees(bytes32 poolId, address feeToken, uint256 feeAmount) internal {
        if (feeAmount == 0) return;

        AppStorage storage s = LibAppStorage.appStorage();
        IFeeFacet.FeeConfig storage feeConfig = s.feeConfigs[poolId];

        (uint256 lpFee, uint256 protocolFee, uint256 traderFee) = LibFee.distributeFee(
            feeAmount,
            feeConfig.lpShareBps,
            feeConfig.protocolShareBps,
            feeConfig.traderShareBps
        );

        // LP fees are accounted through fee growth globals (accumulated per unit of liquidity)
        IPool.PoolState storage state = s.poolStates[poolId];
        IPool.PoolConfig storage config = s.poolConfigs[poolId];

        if (state.liquidity > 0) {
            if (feeToken == config.token0) {
                state.feeGrowthGlobal0X128 += FullMath.mulDiv(lpFee, 1 << 128, state.liquidity);
                state.protocolFees0 += protocolFee;
                // Exclude non-LP fees from reserves so removeLiquidity doesn't over-withdraw
                state.reserve0 -= (protocolFee + traderFee);
            } else {
                state.feeGrowthGlobal1X128 += FullMath.mulDiv(lpFee, 1 << 128, state.liquidity);
                state.protocolFees1 += protocolFee;
                state.reserve1 -= (protocolFee + traderFee);
            }
        }

        // Trader rebate pool accumulation
        if (feeToken == config.token0) {
            s.epochState.totalRebatePool0 += traderFee;
        } else {
            s.epochState.totalRebatePool1 += traderFee;
        }
    }

    /// @dev Record trader activity for rebate qualification
    function _recordTraderActivity(bytes32 poolId, address trader, uint256 volume) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        TraderRewardState storage traderState = s.traderRewards[poolId][trader];

        // Reset if new epoch
        if (traderState.lastActiveEpoch < s.epochState.currentEpoch) {
            traderState.epochSwapCount = 0;
            traderState.epochVolume = 0;
            traderState.lastActiveEpoch = s.epochState.currentEpoch;
        }

        traderState.epochSwapCount++;
        traderState.epochVolume += volume;
    }
}

import "../interfaces/IOraclePegFacet.sol";
