// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../interfaces/IOrderFacet.sol";
import "../interfaces/IPool.sol";
import "../libraries/LibOrder.sol";
import "../libraries/LibSecurity.sol";
import "../libraries/LibTransfer.sol";
import "../libraries/LibSwap.sol";
import "../libraries/LibFee.sol";
import "../storage/AppStorage.sol";
import "../../utils/FullMath.sol";
import "../../utils/TickMath.sol";

/// @title OrderFacet — On-chain limit and stop orders with tick-aligned buckets
/// @notice Allows placing, cancelling, and executing conditional orders
/// @dev Diamond facet — operates on AppStorage via delegatecall
contract OrderFacet is IOrderFacet {
    uint256 internal constant BPS = 10_000;

    /// @inheritdoc IOrderFacet
    function placeOrder(PlaceOrderParams calldata params) external returns (uint256 orderId) {
        LibSecurity.nonReentrantBefore();
        LibSecurity.requireNotPaused();

        AppStorage storage s = LibAppStorage.appStorage();
        IPool.PoolConfig storage config = s.poolConfigs[params.poolId];
        require(config.token0 != address(0), "OrderFacet: pool does not exist");

        // Snap target tick to pool's tick spacing
        int24 alignedTick = TickMath.nearestUsableTick(params.targetTick, int24(config.tickSpacing));

        // Create aligned params
        PlaceOrderParams memory alignedParams = PlaceOrderParams({
            poolId: params.poolId,
            orderType: params.orderType,
            zeroForOne: params.zeroForOne,
            targetTick: alignedTick,
            amount: params.amount,
            expiry: params.expiry
        });

        // Place the order in storage
        orderId = LibOrder.placeOrder(params.poolId, alignedParams);

        // Pull deposit tokens from the user
        address depositToken = params.zeroForOne ? config.token0 : config.token1;
        LibTransfer.pullToken(depositToken, msg.sender, params.amount);

        emit OrderPlaced(
            orderId,
            params.poolId,
            msg.sender,
            params.orderType,
            alignedTick,
            params.amount
        );

        LibSecurity.nonReentrantAfter();
    }

    /// @inheritdoc IOrderFacet
    function cancelOrder(uint256 orderId) external {
        LibSecurity.nonReentrantBefore();

        AppStorage storage s = LibAppStorage.appStorage();
        IOrderFacet.Order storage order = s.orders[orderId];
        require(order.owner == msg.sender, "OrderFacet: not owner");

        // Calculate refund (total - filled)
        uint256 refundAmount = order.amountTotal - order.amountFilled;

        // Cancel in storage
        LibOrder.cancelOrder(orderId);

        // Refund deposited tokens
        IPool.PoolConfig storage config = s.poolConfigs[order.poolId];
        address depositToken = order.zeroForOne ? config.token0 : config.token1;
        if (refundAmount > 0) {
            LibTransfer.pushToken(depositToken, msg.sender, refundAmount);
        }

        emit OrderCancelled(orderId);

        LibSecurity.nonReentrantAfter();
    }

    /// @inheritdoc IOrderFacet
    function executeOrder(uint256 orderId) external returns (uint256 amountOut, uint256 bounty) {
        LibSecurity.nonReentrantBefore();
        LibSecurity.requireNotPaused();

        AppStorage storage s = LibAppStorage.appStorage();
        IOrderFacet.Order storage order = s.orders[orderId];

        require(order.orderId != 0, "OrderFacet: order does not exist");
        require(
            order.status == OrderStatus.Active || order.status == OrderStatus.PartiallyFilled,
            "OrderFacet: order not active"
        );
        require(block.timestamp <= order.expiry, "OrderFacet: order expired");

        IPool.PoolConfig storage config = s.poolConfigs[order.poolId];
        IPool.PoolState storage state = s.poolStates[order.poolId];

        // Verify execution condition
        if (order.orderType == OrderType.Limit) {
            // Limit order: current tick must have crossed the target
            if (order.zeroForOne) {
                require(state.currentTick <= order.targetTick, "OrderFacet: price not reached");
            } else {
                require(state.currentTick >= order.targetTick, "OrderFacet: price not reached");
            }
        }
        // Stop orders: triggered by oracle (simplified — check current tick)

        // Calculate remaining amount to fill
        uint256 remainingAmount = order.amountTotal - order.amountFilled;

        // Execute swap at current pool price
        address tokenIn = order.zeroForOne ? config.token0 : config.token1;
        address tokenOut = order.zeroForOne ? config.token1 : config.token0;

        // Calculate output using sigmoid curve
        amountOut = LibSwap.computeSigmoidSwapOutput(
            remainingAmount,
            order.zeroForOne ? state.reserve0 : state.reserve1,
            order.zeroForOne ? state.reserve1 : state.reserve0,
            config.sigmoidAlpha,
            config.sigmoidK
        );

        // Calculate keeper bounty
        bounty = FullMath.mulDiv(amountOut, s.keeperBountyBps, BPS);
        uint256 userOutput = amountOut - bounty;

        // Update reserves
        if (order.zeroForOne) {
            state.reserve0 += remainingAmount;
            state.reserve1 -= amountOut;
        } else {
            state.reserve1 += remainingAmount;
            state.reserve0 -= amountOut;
        }

        // Mark order as filled
        LibOrder.fillOrder(orderId, remainingAmount);

        // Transfer output to order owner
        LibTransfer.pushToken(tokenOut, order.owner, userOutput);

        // Transfer bounty to keeper (msg.sender)
        if (bounty > 0) {
            LibTransfer.pushToken(tokenOut, msg.sender, bounty);
        }

        emit OrderFilled(orderId, remainingAmount, userOutput);
        emit OrderExecutedByKeeper(orderId, msg.sender, bounty);

        LibSecurity.nonReentrantAfter();
    }

    /// @inheritdoc IOrderFacet
    function getOrder(uint256 orderId) external view returns (Order memory) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.orders[orderId];
    }

    /// @inheritdoc IOrderFacet
    function getOrdersAtTick(bytes32 poolId, int24 tick) external view returns (uint256[] memory orderIds) {
        return LibOrder.getOrdersAtTick(poolId, tick);
    }

    /// @inheritdoc IOrderFacet
    function getActiveOrderCount(bytes32 poolId) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.activeOrderCounts[poolId];
    }

    /// @notice Expire stale orders at a tick (callable by anyone — gas refund incentive)
    function expireOrdersAtTick(bytes32 poolId, int24 tick) external returns (uint256 expiredCount) {
        expiredCount = LibOrder.expireOrders(poolId, tick);
    }
}
