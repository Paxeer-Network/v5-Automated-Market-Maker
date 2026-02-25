---
layout: home
hero:
  name: v5-ASAMM
  text: Adaptive Sigmoid AMM
  tagline: DeFi protocol with progressive fees, on-chain order book, oracle-pegged pools, and Diamond Standard upgradeability
  actions:
    - theme: brand
      text: Get Started
      link: /guide/architecture
    - theme: alt
      text: API Reference
      link: /api/pool-facet
    - theme: alt
      text: View on Paxscan
      link: https://paxscan.paxeer.app/address/0x9595a92d63884d2D9924e0002D45C34d717DB291
features:
  - icon: "~"
    title: Sigmoid Bonding Curve
    details: tanh-based price impact delivers near-zero slippage for small trades while punishing whale manipulation
  - icon: "%"
    title: Progressive Fees
    details: "Quadratic fee scaling: fee(x) = baseFee + impactFee * (x/L)^2 - retail-friendly, whale-resistant"
  - icon: "*"
    title: LP Loyalty Rewards
    details: Time + volume multiplier up to 2x fee share for long-term liquidity providers
  - icon: "@"
    title: Oracle-Pegged Pools
    details: Wrapped assets trade at oracle price with TWAP anchor and circuit breaker protection
  - icon: "#"
    title: On-Chain Order Book
    details: Tick-aligned limit and stop orders with O(1) execution and keeper bounties
  - icon: "+"
    title: Diamond Standard (EIP-2535)
    details: 12 modular facets with zero storage collisions and targeted upgrade capability
---
