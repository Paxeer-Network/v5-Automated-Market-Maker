<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# Changelog

All notable changes to the v5-ASAMM protocol are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-02-25

### Added

- Full Diamond proxy (EIP-2535) with 12 facets: Swap, Liquidity, Pool, Fee, Oracle, OraclePeg, Order, Reward, FlashLoan, DiamondCut, DiamondLoupe, Ownership
- Sigmoid bonding curve with tanh-based price impact (Pade approximant in Q128.128)
- Progressive quadratic fee structure with LP/protocol/trader splits
- Tick-aligned on-chain order book for limit and stop orders
- Oracle-pegged pool support with TWAP anchor and circuit breaker
- LP loyalty multiplier (time + volume) and epoch-based trader rebates
- Periphery contracts: Router, Quoter, PositionManager, OrderManager, PositionDescriptor, Multicall, SelfPermit
- Custom ERC-20 (with EIP-2612 permit), ERC-721, and ERC-721Permit (EIP-4494)
- Custom math libraries: FullMath (512-bit mulDiv), FixedPointMath (Q128.128), SqrtPriceMath, TickMath
- Security utilities: ReentrancyGuard, Pausable, Owned, SafeTransfer
- 53 unit tests across 5 test suites (Diamond, ERC20, FullMath, FixedPointMath, LibFee)
- Hardhat and Foundry dual build system
- EventEmitter indexer with PostgreSQL, Redis, and GraphQL API
- TypeScript SDK with typed contract interfaces and deployment addresses
- VitePress documentation site with full API reference
- GitHub Actions CI/CD: compile, test, lint, security analysis, release
- Dependabot configuration for automated dependency updates

### Known Limitations

- tanh Pade approximant overflows for Q128 inputs above ~0.01; production deployment should use CORDIC or lookup table
- SwapFacet does not yet iterate through tick crossings or drain order buckets inline
- Router token pull/approve are stubs pending full Diamond token flow integration
- Foundry fuzz tests and integration tests are not yet written

---

## License

Licensed under the **GNU General Public License v3.0**--see [LICENSE](LICENSE) for terms.

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
