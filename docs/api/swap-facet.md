<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>


The SwapFacet executes token swaps using the sigmoid bonding curve with progressive fee calculation.

## Functions

### swap

Execute a swap against a pool.

```solidity
function swap(SwapParams calldata params) external returns (SwapResult memory result)
```

**Parameters (SwapParams):**

| Name | Type | Description |
|------|------|-------------|
| poolId | bytes32 | The pool to swap against |
| zeroForOne | bool | true = sell token0 for token1, false = reverse |
| amountSpecified | int256 | Positive = exact input, negative = exact output |
| sqrtPriceLimitX96 | uint160 | Price limit (0 = no limit) |
| recipient | address | Address to receive output tokens |
| deadline | uint256 | Transaction deadline (unix timestamp) |

**Returns (SwapResult):**

| Field | Type | Description |
|-------|------|-------------|
| amount0 | int256 | Token0 delta (negative = sent to user) |
| amount1 | int256 | Token1 delta (negative = sent to user) |
| sqrtPriceX96After | uint160 | Price after swap |
| tickAfter | int24 | Tick after swap |
| liquidityAfter | uint128 | Active liquidity after swap |
| feeAmount | uint256 | Total fee charged |

**Events:** Swap, SwapExecuted (via EventEmitter)

**Reverts:**
- "SwapFacet: expired" - block.timestamp > deadline
- "SwapFacet: pool not initialized"
- "SwapFacet: zero amount"
- "SwapFacet: price limit reached"

### Swap Mechanics

1. The swap engine iterates through ticks, computing output amounts using the sigmoid curve
2. At each step, the progressive fee is calculated: `fee = baseFee + impactFee * (stepSize/liquidity)^2`
3. Fees are split: 70% LP, 20% protocol, 10% trader rebate pool
4. Oracle observations are recorded for TWAP
5. EventEmitter is notified with full before/after state

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
