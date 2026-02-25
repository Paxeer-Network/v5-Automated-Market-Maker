# v5-ASAMM Protocol -- Claude Instructions

## Overview

v5-ASAMM is an Adaptive Sigmoid Automated Market Maker for Paxeer Network (Chain ID 125). It implements an EIP-2535 Diamond Standard architecture with 12 facets and zero external Solidity dependencies.

## Repository Layout

- `src/` -- Solidity contracts: core (diamond, facets, libraries, storage, interfaces), periphery, tokens, utils
- `test/` -- Hardhat test suites (Mocha/Chai)
- `scripts/` -- Deployment and utility scripts
- `docs/` -- VitePress documentation site with full API reference
- `indexer/` -- Event indexer with Apollo GraphQL, PostgreSQL, and Redis
- `sdk/` -- TypeScript SDK with typed ethers v6 contract interfaces

## Build and Test

```bash
npm run compile         # Hardhat compile
forge build             # Foundry compile
npm test                # Hardhat tests
forge test -vvv         # Foundry tests
npm run lint            # Solhint + ESLint
npm run slither         # Slither static analysis
```

## Constraints

1. **No external Solidity deps** -- every contract is custom (no OpenZeppelin, no Solmate)
2. **Solidity 0.8.27** with optimizer (200 runs) and viaIR
3. **Single AppStorage** -- all facets share one storage struct at `keccak256("v5asamm.app.storage")`
4. **NatSpec required** on all public/external functions
5. **Secrets in .env only** -- never hardcode keys or mnemonics
6. **Tests required** for every new public function

## Key Formulas

- Sigmoid: `P(x) = P_mid * (1 + k * tanh(a * x / L))`
- Fee: `fee(x) = baseFee + impactFee * (x/L)^2`
- LP loyalty: `multiplier = time_factor * sqrt(volume_factor)`

## Network

- Paxeer Network, Chain ID 125
- RPC: `https://public-rpc.paxeer.app/rpc`
- Explorer: `https://paxscan.paxeer.app`

## License

GPL-3.0-only. Copyright (C) 2026 PaxLabs Inc.