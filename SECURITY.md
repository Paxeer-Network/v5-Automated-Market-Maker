<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# Security Policy

## Reporting Vulnerabilities

If you discover a security vulnerability, report it responsibly:

1. **Do not** open a public issue
2. Send details to [security@paxeer.app](mailto:security@paxeer.app)
3. Include steps to reproduce the issue
4. Allow 48 hours for an initial response

## Scope

The following areas are in scope for security reports:

- Smart contract vulnerabilities (reentrancy, overflow, access control)
- Economic exploits (oracle manipulation, flash loan attacks, fee extraction)
- Diamond proxy storage collisions
- Order book manipulation

## Bug Bounty

Severity-based rewards for confirmed vulnerabilities:

| Severity | Impact | Reward |
|----------|--------|--------|
| **Critical** | Direct fund loss | Up to $100,000 |
| **High** | Protocol disruption | Up to $25,000 |
| **Medium** | Limited impact | Up to $5,000 |
| **Low** | Informational | Up to $1,000 |

## Security Measures

- Custom `ReentrancyGuard` on all state-mutating facets
- TWAP oracle (not spot) as the primary price anchor
- Progressive fees make flash-loan-sized trades prohibitively expensive
- Circuit breaker halts pools when oracle data is stale
- Slippage protection and deadline enforcement in the Router
- Single `AppStorage` struct at a deterministic storage slot prevents collisions

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