// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../core/interfaces/IOrderFacet.sol";
import "../core/interfaces/IERC20.sol";
import "../utils/SafeTransfer.sol";
import "../utils/ReentrancyGuard.sol";

/// @title OrderManager — User-facing limit/stop order placement and management
/// @notice Stateless periphery wrapper around the Diamond's OrderFacet
/// @dev Custom implementation — no external dependencies
contract OrderManager is ReentrancyGuard {
    using SafeTransfer for address;

    address public immutable diamond;

    error DeadlineExpired();
    error ZeroAddress();

    struct PlaceLimitOrderParams {
        bytes32 poolId;
        bool zeroForOne;
        int24 targetTick;
        uint256 amount;
        uint256 expiry;
        uint256 deadline;
    }

    struct PlaceStopOrderParams {
        bytes32 poolId;
        bool zeroForOne;
        int24 targetTick;
        uint256 amount;
        uint256 expiry;
        uint256 deadline;
    }

    event LimitOrderPlaced(uint256 indexed orderId, bytes32 indexed poolId, address indexed owner);
    event StopOrderPlaced(uint256 indexed orderId, bytes32 indexed poolId, address indexed owner);

    constructor(address _diamond) {
        if (_diamond == address(0)) revert ZeroAddress();
        diamond = _diamond;
    }

    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        _;
    }

    /// @notice Place a limit order
    /// @param params The limit order parameters
    /// @return orderId The created order ID
    function placeLimitOrder(
        PlaceLimitOrderParams calldata params
    ) external nonReentrant checkDeadline(params.deadline) returns (uint256 orderId) {
        IOrderFacet.PlaceOrderParams memory orderParams = IOrderFacet.PlaceOrderParams({
            poolId: params.poolId,
            orderType: IOrderFacet.OrderType.Limit,
            zeroForOne: params.zeroForOne,
            targetTick: params.targetTick,
            amount: params.amount,
            expiry: params.expiry
        });

        orderId = IOrderFacet(diamond).placeOrder(orderParams);

        emit LimitOrderPlaced(orderId, params.poolId, msg.sender);
    }

    /// @notice Place a stop order
    /// @param params The stop order parameters
    /// @return orderId The created order ID
    function placeStopOrder(
        PlaceStopOrderParams calldata params
    ) external nonReentrant checkDeadline(params.deadline) returns (uint256 orderId) {
        IOrderFacet.PlaceOrderParams memory orderParams = IOrderFacet.PlaceOrderParams({
            poolId: params.poolId,
            orderType: IOrderFacet.OrderType.Stop,
            zeroForOne: params.zeroForOne,
            targetTick: params.targetTick,
            amount: params.amount,
            expiry: params.expiry
        });

        orderId = IOrderFacet(diamond).placeOrder(orderParams);

        emit StopOrderPlaced(orderId, params.poolId, msg.sender);
    }

    /// @notice Cancel an existing order
    /// @param orderId The order to cancel
    function cancelOrder(uint256 orderId) external nonReentrant {
        IOrderFacet(diamond).cancelOrder(orderId);
    }

    /// @notice Execute a pending order as a keeper
    /// @param orderId The order to execute
    /// @return amountOut Output amount sent to order owner
    /// @return bounty Keeper bounty received
    function executeOrder(uint256 orderId) external nonReentrant returns (uint256 amountOut, uint256 bounty) {
        (amountOut, bounty) = IOrderFacet(diamond).executeOrder(orderId);
    }

    /// @notice Batch execute multiple orders (keeper utility)
    /// @param orderIds Array of order IDs to execute
    /// @return totalBounty Total keeper bounty earned
    function batchExecuteOrders(uint256[] calldata orderIds) external nonReentrant returns (uint256 totalBounty) {
        for (uint256 i = 0; i < orderIds.length; i++) {
            try IOrderFacet(diamond).executeOrder(orderIds[i]) returns (uint256, uint256 bounty) {
                totalBounty += bounty;
            } catch {
                // Skip failed executions
                continue;
            }
        }
    }

    /// @notice Get order details
    /// @param orderId The order ID
    /// @return The order details
    function getOrder(uint256 orderId) external view returns (IOrderFacet.Order memory) {
        return IOrderFacet(diamond).getOrder(orderId);
    }

    /// @notice Get all active orders at a tick
    function getOrdersAtTick(bytes32 poolId, int24 tick) external view returns (uint256[] memory) {
        return IOrderFacet(diamond).getOrdersAtTick(poolId, tick);
    }

    /// @notice Get active order count for a pool
    function getActiveOrderCount(bytes32 poolId) external view returns (uint256) {
        return IOrderFacet(diamond).getActiveOrderCount(poolId);
    }
}
