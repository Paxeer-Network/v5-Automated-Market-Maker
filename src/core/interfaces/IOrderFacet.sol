// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title IOrderFacet — Interface for on-chain limit and stop orders
/// @notice Tick-aligned bucket order book for gas-efficient execution
interface IOrderFacet {
    enum OrderType {
        Limit,
        Stop
    }

    enum OrderStatus {
        Active,
        PartiallyFilled,
        Filled,
        Cancelled,
        Expired
    }

    struct Order {
        uint256 orderId;
        bytes32 poolId;
        address owner;
        OrderType orderType;
        bool zeroForOne; // Direction: true = sell token0 for token1
        int24 targetTick; // Tick at which the order executes
        uint256 amountTotal; // Total amount to trade
        uint256 amountFilled; // Amount already filled
        uint256 depositTimestamp; // When the order was placed
        uint256 expiry; // Expiration timestamp (0 = no expiry)
        OrderStatus status;
    }

    struct PlaceOrderParams {
        bytes32 poolId;
        OrderType orderType;
        bool zeroForOne;
        int24 targetTick;
        uint256 amount;
        uint256 expiry; // 0 for default TTL
    }

    event OrderPlaced(
        uint256 indexed orderId,
        bytes32 indexed poolId,
        address indexed owner,
        OrderType orderType,
        int24 targetTick,
        uint256 amount
    );

    event OrderFilled(uint256 indexed orderId, uint256 amountFilled, uint256 amountOut);
    event OrderPartiallyFilled(uint256 indexed orderId, uint256 amountFilled, uint256 remaining);
    event OrderCancelled(uint256 indexed orderId);
    event OrderExpired(uint256 indexed orderId);
    event OrderExecutedByKeeper(uint256 indexed orderId, address indexed keeper, uint256 bounty);

    /// @notice Place a new limit or stop order
    function placeOrder(PlaceOrderParams calldata params) external returns (uint256 orderId);

    /// @notice Cancel an active order and refund deposited tokens
    function cancelOrder(uint256 orderId) external;

    /// @notice Execute a pending order (callable by anyone — keeper bounty incentive)
    /// @param orderId The order to execute
    /// @return amountOut The output amount received
    /// @return bounty The keeper bounty paid
    function executeOrder(uint256 orderId) external returns (uint256 amountOut, uint256 bounty);

    /// @notice Get order details
    function getOrder(uint256 orderId) external view returns (Order memory);

    /// @notice Get all active order IDs at a given tick for a pool
    function getOrdersAtTick(bytes32 poolId, int24 tick) external view returns (uint256[] memory orderIds);

    /// @notice Get the total number of active orders for a pool
    function getActiveOrderCount(bytes32 poolId) external view returns (uint256);
}
