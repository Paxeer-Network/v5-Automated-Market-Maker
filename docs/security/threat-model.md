<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# Security Model

## Threat Matrix

| Threat | Severity | Mitigation |
|--------|----------|------------|
| Reentrancy | Critical | Custom ReentrancyGuard on all state-mutating facets (EIP-1153 tstore/tload) |
| Oracle manipulation | High | TWAP (not spot) as primary anchor; staleness circuit breaker |
| Flash loan attacks | High | Progressive fees make large instant trades prohibitively expensive |
| Sandwich attacks | High | Slippage protection in Router; deadline enforcement; quadratic fees |
| Storage collision | High | Single AppStorage struct at deterministic slot (EIP-2535 pattern) |
| Facet selector clash | Medium | DiamondCutFacet validates no duplicate selectors on upgrade |
| Integer overflow | Medium | Solidity 0.8.27 checked math; unchecked only in proven-safe paths |
| Unauthorized upgrade | High | OwnershipFacet restricts diamondCut to owner |
| Token transfer failure | Medium | SafeTransfer library handles non-standard ERC-20 returns |
| Price manipulation | High | Sigmoid curve bounds max price impact; fees punish large trades |

## Access Control

| Operation | Who Can Call |
|-----------|-------------|
| Create pool | Anyone (permissionless) |
| Initialize pool | Anyone |
| Swap | Anyone |
| Add/remove liquidity | Anyone |
| Collect LP fees | Position owner only |
| Collect protocol fees | Owner or treasury |
| Set fee config | Owner only |
| Set oracle peg | Owner only |
| Pause/unpause | Owner or pause guardians |
| Diamond cut (upgrade) | Owner only |
| Execute orders | Anyone (keeper bounty) |
| Advance epoch | Anyone |

## Reentrancy Protection

The protocol uses EIP-1153 transient storage for the reentrancy guard:

```solidity
// Before state mutation
tstore(REENTRANCY_SLOT, 2)  // _ENTERED

// After state mutation
tstore(REENTRANCY_SLOT, 1)  // _NOT_ENTERED
```

Transient storage is cleared at the end of each transaction, saving approximately 2,600 gas compared to traditional SSTORE-based guards.

## Flash Loan Safety

Flash loans are safe because:
1. The fee (default 9 bps) is enforced at the protocol level
2. The callback must return a specific magic value
3. Tokens are pulled back in the same transaction
4. The progressive fee structure makes flash-loan-based price manipulation unprofitable

## Upgrade Security

Current: Owner-controlled diamondCut with no timelock.

Planned upgrade path:
1. Phase 1 (current): Owner-controlled diamondCut
2. Phase 2: 48-hour timelock on all facet upgrades
3. Phase 3: Governance token + on-chain voting
4. Phase 4: Freeze diamondCut permanently (immutable)

## Audit Status

- Static analysis: Slither configured (slither.config.json)
- Fuzz testing: Foundry fuzz tests with 10,000+ runs per property
- Unit tests: 23 Hardhat tests covering all facets
- Integration tests: 7 E2E scenario tests
- Live tests: 23/23 checks passing on Paxeer mainnet

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
