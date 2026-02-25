<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# Fixed-Point Arithmetic

## Q128.128 Format

v5-ASAMM uses Q128.128 fixed-point numbers for high-precision arithmetic without floating-point operations. A Q128.128 number uses 128 bits for the integer part and 128 bits for the fractional part, stored in a uint256.

```
value = raw_uint256 / 2^128
```

### Constants

| Name | Value | Meaning |
|------|-------|---------|
| Q128 | 2^128 | The scaling factor (1.0 in Q128.128) |
| HALF_Q128 | 2^127 | 0.5 in Q128.128 (for rounding) |

### Operations

**Multiplication**: `(a * b) >> 128` using FullMath.mulDiv to avoid overflow
**Division**: `(a << 128) / b` with overflow checks
**Addition/Subtraction**: Direct uint256 add/sub (same scale)

## FullMath Library

The `FullMath` library provides 512-bit intermediate multiplication to prevent overflow when multiplying two uint256 values:

### mulDiv

```solidity
function mulDiv(uint256 a, uint256 b, uint256 denominator) 
    internal pure returns (uint256 result)
```

Computes `(a * b) / denominator` with full 512-bit precision for the intermediate product. This is critical for Q128.128 multiplication where the intermediate result can be up to 512 bits.

**Algorithm**:
1. Compute the 512-bit product `a * b` as two 256-bit words (prod0, prod1)
2. If prod1 == 0, simple division: prod0 / denominator
3. Otherwise, use the Knuth algorithm for 512-bit by 256-bit division

### mulDivRoundingUp

Same as mulDiv but rounds up instead of down. Used when computing minimum amounts to ensure no value is lost.

## SqrtPriceMath Library

Converts between token amounts and sqrt price ranges.

### Key Functions

**getAmount0Delta**: Token0 amount for a price range change
```
amount0 = liquidity * (1/sqrtPriceA - 1/sqrtPriceB)
```

**getAmount1Delta**: Token1 amount for a price range change
```
amount1 = liquidity * (sqrtPriceB - sqrtPriceA)
```

**getNextSqrtPriceFromAmount0RoundingUp**: Next price after adding/removing token0
**getNextSqrtPriceFromAmount1RoundingDown**: Next price after adding/removing token1

## TickMath Library

Converts between tick indices and sqrtPriceX96 values.

### getSqrtRatioAtTick

```solidity
function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96)
```

Computes `sqrt(1.0001^tick) * 2^96` using a binary decomposition approach:
1. Take the absolute value of the tick
2. For each bit of the tick, multiply by a precomputed factor
3. If tick is negative, invert the result

### getTickAtSqrtRatio

```solidity
function getTickAtSqrtRatio(uint160 sqrtPriceX96) internal pure returns (int24 tick)
```

Computes the largest tick such that `getSqrtRatioAtTick(tick) <= sqrtPriceX96`. Uses a binary search approach with precomputed magic numbers.

### nearestUsableTick

```solidity
function nearestUsableTick(int24 tick, int24 tickSpacing) internal pure returns (int24)
```

Rounds a tick to the nearest multiple of tickSpacing.
```

---

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
