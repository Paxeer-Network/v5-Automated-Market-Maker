// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../storage/AppStorage.sol";
import "../interfaces/IOrderFacet.sol";

/// @title LibOrder — Tick-aligned bucket order book data structures
/// @notice Manages on-chain limit and stop orders using tick-aligned buckets
/// @dev O(1) insertion (append to bucket), O(1) drain (process entire bucket)
///      Custom implementation — no external dependencies
library LibOrder {
    error OrderDoesNotExist();
    error OrderNotActive();
    error OrderAlreadyFilled();
    error MaxOrdersExceeded();
    error OrderTooSmall();
    error InvalidExpiry();
    error NotOrderOwner();

    /// @notice Place a new order into the tick-aligned bucket
    /// @param poolId The pool identifier
    /// @param params The order parameters
    /// @return orderId The newly created order ID
    function placeOrder(
        bytes32 poolId,
        IOrderFacet.PlaceOrderParams memory params
    ) internal returns (uint256 orderId) {
        AppStorage storage s = LibAppStorage.appStorage();

        // Validate constraints
        if (params.amount < s.minOrderSize) revert OrderTooSmall();
        if (s.activeOrderCounts[poolId] >= s.maxOrdersPerPool) revert MaxOrdersExceeded();

        // Compute expiry
        uint256 expiry = params.expiry > 0 ? params.expiry : block.timestamp + s.defaultOrderTTL;
        if (expiry <= block.timestamp) revert InvalidExpiry();

        // Create the order
        orderId = s.nextOrderId++;

        s.orders[orderId] = IOrderFacet.Order({
            orderId: orderId,
            poolId: poolId,
            owner: msg.sender,
            orderType: params.orderType,
            zeroForOne: params.zeroForOne,
            targetTick: params.targetTick,
            amountTotal: params.amount,
            amountFilled: 0,
            depositTimestamp: block.timestamp,
            expiry: expiry,
            status: IOrderFacet.OrderStatus.Active
        });

        // Add to tick bucket
        s.orderBuckets[poolId][params.targetTick].orderIds.push(orderId);
        s.activeOrderCounts[poolId]++;
    }

    /// @notice Cancel an active order
    /// @param orderId The order to cancel
    function cancelOrder(uint256 orderId) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        IOrderFacet.Order storage order = s.orders[orderId];

        if (order.orderId == 0) revert OrderDoesNotExist();
        if (order.owner != msg.sender) revert NotOrderOwner();
        if (order.status != IOrderFacet.OrderStatus.Active &&
            order.status != IOrderFacet.OrderStatus.PartiallyFilled) {
            revert OrderNotActive();
        }

        order.status = IOrderFacet.OrderStatus.Cancelled;
        s.activeOrderCounts[order.poolId]--;
    }

    /// @notice Drain all fillable orders at a given tick during a swap
    /// @dev Called by SwapFacet when the price crosses a tick with pending orders
    /// @param poolId The pool identifier
    /// @param tick The tick being crossed
    /// @return totalAmountToFill The total amount of orders to fill at this tick
    /// @return orderIdsToFill Array of order IDs that are ready to fill
    function drainBucket(
        bytes32 poolId,
        int24 tick
    ) internal view returns (uint256 totalAmountToFill, uint256[] memory orderIdsToFill) {
        AppStorage storage s = LibAppStorage.appStorage();
        OrderBucket storage bucket = s.orderBuckets[poolId][tick];

        uint256 count = 0;
        uint256 total = 0;

        // First pass: count fillable orders
        for (uint256 i = bucket.headIndex; i < bucket.orderIds.length; i++) {
            uint256 oid = bucket.orderIds[i];
            IOrderFacet.Order storage order = s.orders[oid];

            if (order.status == IOrderFacet.OrderStatus.Active ||
                order.status == IOrderFacet.OrderStatus.PartiallyFilled) {
                if (block.timestamp <= order.expiry) {
                    count++;
                    total += order.amountTotal - order.amountFilled;
                }
            }
        }

        // Second pass: collect order IDs
        orderIdsToFill = new uint256[](count);
        uint256 idx = 0;
        for (uint256 i = bucket.headIndex; i < bucket.orderIds.length; i++) {
            uint256 oid = bucket.orderIds[i];
            IOrderFacet.Order storage order = s.orders[oid];

            if (order.status == IOrderFacet.OrderStatus.Active ||
                order.status == IOrderFacet.OrderStatus.PartiallyFilled) {
                if (block.timestamp <= order.expiry) {
                    orderIdsToFill[idx++] = oid;
                }
            }
        }

        totalAmountToFill = total;
    }

    /// @notice Mark an order as filled (or partially filled)
    /// @param orderId The order to update
    /// @param filledAmount The amount filled in this execution
    function fillOrder(uint256 orderId, uint256 filledAmount) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        IOrderFacet.Order storage order = s.orders[orderId];

        order.amountFilled += filledAmount;

        if (order.amountFilled >= order.amountTotal) {
            order.status = IOrderFacet.OrderStatus.Filled;
            s.activeOrderCounts[order.poolId]--;
        } else {
            order.status = IOrderFacet.OrderStatus.PartiallyFilled;
        }
    }

    /// @notice Expire stale orders at a given tick
    /// @param poolId The pool identifier
    /// @param tick The tick to clean up
    /// @return expiredCount The number of orders expired
    function expireOrders(bytes32 poolId, int24 tick) internal returns (uint256 expiredCount) {
        AppStorage storage s = LibAppStorage.appStorage();
        OrderBucket storage bucket = s.orderBuckets[poolId][tick];

        for (uint256 i = bucket.headIndex; i < bucket.orderIds.length; i++) {
            uint256 oid = bucket.orderIds[i];
            IOrderFacet.Order storage order = s.orders[oid];

            if ((order.status == IOrderFacet.OrderStatus.Active ||
                 order.status == IOrderFacet.OrderStatus.PartiallyFilled) &&
                block.timestamp > order.expiry) {
                order.status = IOrderFacet.OrderStatus.Expired;
                s.activeOrderCounts[poolId]--;
                expiredCount++;
            }
        }

        // Advance head index past processed/expired orders
        while (bucket.headIndex < bucket.orderIds.length) {
            uint256 oid = bucket.orderIds[bucket.headIndex];
            IOrderFacet.Order storage order = s.orders[oid];
            if (order.status == IOrderFacet.OrderStatus.Active ||
                order.status == IOrderFacet.OrderStatus.PartiallyFilled) {
                break;
            }
            bucket.headIndex++;
        }
    }

    /// @notice Get all active order IDs at a tick
    function getOrdersAtTick(bytes32 poolId, int24 tick) internal view returns (uint256[] memory) {
        AppStorage storage s = LibAppStorage.appStorage();
        OrderBucket storage bucket = s.orderBuckets[poolId][tick];

        uint256 count = 0;
        for (uint256 i = bucket.headIndex; i < bucket.orderIds.length; i++) {
            IOrderFacet.Order storage order = s.orders[bucket.orderIds[i]];
            if (order.status == IOrderFacet.OrderStatus.Active ||
                order.status == IOrderFacet.OrderStatus.PartiallyFilled) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 idx = 0;
        for (uint256 i = bucket.headIndex; i < bucket.orderIds.length; i++) {
            IOrderFacet.Order storage order = s.orders[bucket.orderIds[i]];
            if (order.status == IOrderFacet.OrderStatus.Active ||
                order.status == IOrderFacet.OrderStatus.PartiallyFilled) {
                result[idx++] = bucket.orderIds[i];
            }
        }

        return result;
    }
}
