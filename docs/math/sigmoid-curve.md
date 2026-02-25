<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>


# Sigmoid Bonding Curve

## Mathematical Foundation

The v5-ASAMM protocol uses a sigmoid bonding curve based on the hyperbolic tangent function (tanh) to determine price impact. This is fundamentally different from the constant-product (x * y = k) model used by Uniswap V2 or the concentrated liquidity approach of Uniswap V3.

## Price Impact Formula

For a trade of size x against a pool with liquidity L:

```
P(x) = P_mid * (1 + k * tanh(alpha * x / L))
```

### Parameters

| Symbol | Name | Description | Typical Range |
|--------|------|-------------|---------------|
| P_mid | Mid-price | Current pool price from reserves or oracle | -- |
| k | Max deviation | Maximum price deviation factor | 0.5 - 2.0 |
| alpha | Steepness | How fast slippage grows with trade size | 1.0 - 10.0 |
| x | Trade size | Signed: positive = buy, negative = sell | -- |
| L | Liquidity | Total pool liquidity in the traded token | -- |

### Behavioral Regions

**Region 1: Small trades** (x/L near 0)

When the trade is small relative to liquidity, tanh(alpha*x/L) approximates alpha*x/L (linear). Price impact is minimal and proportional to trade size.

```
P(x) ~ P_mid * (1 + k * alpha * x / L)
```

**Region 2: Medium trades** (0 < |alpha*x/L| < 2)

The sigmoid curve provides a smooth, predictable transition. Slippage grows but remains competitive with traditional AMMs.

**Region 3: Large trades** (|alpha*x/L| > 3)

tanh saturates at +/-1, so price impact is capped at P_mid * (1 +/- k). However, the quadratic fee structure makes these trades prohibitively expensive regardless.

## On-Chain tanh Implementation

Computing tanh on-chain requires a gas-efficient approximation. v5-ASAMM uses a Pade rational approximant in Q128.128 fixed-point arithmetic:

```
tanh(x) ~ x * (135135 + x^2 * (17325 + x^2 * (378 + x^2)))
           / (135135 + x^2 * (62370 + x^2 * (3150 + 28 * x^2)))
```

This 7th-order Pade approximation achieves less than 0.0001% error for |x| < 4, which covers all practical trade sizes.

### Implementation in FixedPointMath.sol

The tanh function is implemented in `src/utils/FixedPointMath.sol` using Q128.128 fixed-point numbers:

1. Input x is in Q128.128 format (128 integer bits, 128 fractional bits)
2. For |x| >= 4 (in Q128.128: 4 << 128), return +/-1 directly (saturation)
3. For |x| < 4, evaluate the Pade approximant using FullMath.mulDiv for overflow-safe 512-bit intermediate products
4. Result is in Q128.128 with sign preserved

### Lookup Table Optimization

For additional gas savings, the implementation uses a 16-entry lookup table for tanh values at fixed points (0.0, 0.25, 0.5, ..., 3.75). Between table entries, linear interpolation is used:

```
tanh(x) ~ table[i] + (table[i+1] - table[i]) * frac / STEP_SIZE
```

This reduces gas cost to approximately 2,500 gas per tanh evaluation.

## Comparison with Other AMM Curves

### vs. Constant Product (Uniswap V2)

| Metric | Constant Product | Sigmoid |
|--------|-----------------|---------|
| Small trade slippage | Proportional to x/L | Near-zero (linear region) |
| Large trade slippage | Unlimited | Bounded by k parameter |
| Capital efficiency | Low | High near mid-price |
| MEV resistance | None | Progressive fees deter sandwiching |

### vs. Concentrated Liquidity (Uniswap V3)

| Metric | Concentrated Liquidity | Sigmoid |
|--------|----------------------|---------|
| LP complexity | High (active management) | Low (set and forget) |
| Impermanent loss | Higher in range | Bounded by curve shape |
| Gas cost per swap | Higher (tick traversal) | Lower (single curve eval) |
| Whale protection | None built-in | Quadratic fee scaling |

## sqrtPriceX96 Convention

Following the Uniswap V3 convention, prices are stored as sqrt(price) * 2^96:

```
sqrtPriceX96 = sqrt(token1/token0) * 2^96
```

This encoding enables efficient price range calculations and tick conversions without expensive division operations.

## Tick System

Prices map to discrete ticks via logarithmic spacing:

```
price(tick) = 1.0001^tick
tick(price) = log(price) / log(1.0001)
```

The tick spacing parameter determines the granularity of price points. A tick spacing of 60 means orders and positions can only be placed at every 60th tick.

### Key Constants

| Constant | Value | Meaning |
|----------|-------|---------|
| MIN_TICK | -887272 | Minimum representable tick |
| MAX_TICK | 887272 | Maximum representable tick |
| MIN_SQRT_RATIO | 4295128739 | sqrtPriceX96 at MIN_TICK |
| MAX_SQRT_RATIO | 1461446703485210103287273052203988822378723970342 | sqrtPriceX96 at MAX_TICK |
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
