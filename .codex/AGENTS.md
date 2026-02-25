# v5-ASAMM Protocol -- Codex Agent Instructions

## Overview

v5-ASAMM is an Adaptive Sigmoid Automated Market Maker built for Paxeer Network (Chain ID 125). The protocol uses EIP-2535 Diamond Standard with 12 facets and zero external Solidity dependencies.

## Repository Structure

```
src/              Solidity contracts (core, periphery, tokens, utils)
test/             Hardhat test suites
scripts/          Deployment and utility scripts
docs/             VitePress documentation site
indexer/          GraphQL event indexer (PostgreSQL + Redis)
sdk/              TypeScript SDK for frontend integration
```

## Build Commands

```bash
npm run compile        # Compile with Hardhat
forge build            # Compile with Foundry
npm test               # Run Hardhat tests
forge test -vvv        # Run Foundry tests
npm run lint           # Lint Solidity + TypeScript
npm run slither        # Static analysis
```

## Rules

1. All Solidity code is custom -- do not introduce OpenZeppelin, Solmate, or other external imports
2. Solidity version is locked to 0.8.27
3. All facets read/write through the shared `AppStorage` struct
4. NatSpec documentation is required on all public and external functions
5. Private keys and secrets belong in `.env` (git-ignored), never in source
6. Unit tests are required for every new public function
7. The Diamond proxy pattern means function selectors must not collide across facets

## Key Architecture Decisions

- Sigmoid bonding curve with Pade tanh approximant in Q128.128 fixed-point
- Progressive quadratic fees: `fee(x) = baseFee + impactFee * (x/L)^2`
- Tick-aligned order book with FIFO bucket queues
- Oracle-pegged pools with TWAP anchor and circuit breaker
- LP loyalty multiplier combining time and volume factors
- Single `AppStorage` struct at `keccak256("v5asamm.app.storage")`

## Network

- Chain: Paxeer Network
- Chain ID: 125
- RPC: https://public-rpc.paxeer.app/rpc
- Explorer: https://paxscan.paxeer.app

## License

GPL-3.0-only. Copyright (C) 2026 PaxLabs Inc.
