<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>


# OrderFacet API Reference

The OrderFacet implements an on-chain order book with tick-aligned limit and stop orders.

## Types

### OrderType
- `Limit` (0) - Executes when pool price reaches target tick
- `Stop` (1) - Executes when oracle price crosses threshold

### OrderStatus
- `Active` (0) - Order is open
- `PartiallyFilled` (1) - Partially executed
- `Filled` (2) - Fully executed
- `Cancelled` (3) - Cancelled by owner
- `Expired` (4) - Past expiry timestamp

## Functions

### placeOrder

Place a new limit or stop order.

```solidity
function placeOrder(PlaceOrderParams calldata params) external returns (uint256 orderId)
```

**Parameters (PlaceOrderParams):**

| Name | Type | Description |
|------|------|-------------|
| poolId | bytes32 | Target pool |
| orderType | OrderType | 0 = Limit, 1 = Stop |
| zeroForOne | bool | Direction: true = sell token0 for token1 |
| targetTick | int24 | Tick at which order executes |
| amount | uint256 | Total amount to trade |
| expiry | uint256 | Expiration timestamp (0 = default TTL of 30 days) |

### cancelOrder

Cancel an active order and refund deposited tokens.

```solidity
function cancelOrder(uint256 orderId) external
```

Only the order owner can cancel.

### executeOrder

Execute a pending order. Callable by anyone (keeper bounty incentive).

```solidity
function executeOrder(uint256 orderId) external returns (uint256 amountOut, uint256 bounty)
```

Keepers earn 0.01% of order value as bounty.

### getOrder

Get order details.

```solidity
function getOrder(uint256 orderId) external view returns (Order memory)
```

### getOrdersAtTick

Get all active order IDs at a given tick.

```solidity
function getOrdersAtTick(bytes32 poolId, int24 tick) external view returns (uint256[] memory)
```

### getActiveOrderCount

Get total active orders for a pool.

```solidity
function getActiveOrderCount(bytes32 poolId) external view returns (uint256)
```

---

## License

Licensed under the **GNU General Public License v3.0**--see [LICENSE](../../LICENSE) for terms.

```
Copyright (C) 2026 PaxLabs Inc.
SPDX-License-Identifier: GPL-3.0-only
```

## Contact & Resources

| Resource | Link |
|----------|------|
| **Protocol Documentation** | [docs.hyperpaxeer.com](https://docs.hyperpaxeer.com) |
| **Block Explorer** | [paxscan.paxeer.app](https://paxscan.paxeer.app) |
| **Sidiora Exchange** | [app.hyperpaxeer.com](https://sidiora.hyperpaxeer.com) |
| **Website** | [paxeer.app](https://paxeer.app) |
| **Twitter/X** | [@paxeer_app](https://x.com/paxeer_app) |
| **General Inquiries** | [infopaxeer@paxeer.app](mailto:infopaxeer@paxeer.app) |
| **Security Reports** | [security@paxeer.app](mailto:security@paxeer.app) |
