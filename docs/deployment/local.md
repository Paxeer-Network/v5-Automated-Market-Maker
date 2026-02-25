<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

# Local Development

## Prerequisites

- Node.js >= 18.0.0
- npm or yarn
- Foundry (forge, cast, anvil) - optional for fuzz testing

## Setup

```bash
git clone https://github.com/Paxeer-Network/v5-Automated-Market-Maker.git
cd v5-Automated-Market-Maker
npm install
```

## Compile

```bash
# Hardhat compilation
npm run compile

# Foundry compilation
npm run compile:forge
```

## Test

```bash
# Hardhat unit tests
npm test

# Foundry fuzz tests
npm run test:forge

# Extended fuzzing (10,000 runs)
npm run test:fuzz

# Gas report
npm run test:gas

# Coverage
npm run test:coverage
```

## Local Deployment

```bash
# Deploy to Hardhat local network
npm run deploy:local
```

This deploys:
1. Diamond proxy
2. 12 facets (3 infrastructure + 9 business logic)
3. Periphery contracts (Router, Quoter, PositionManager, OrderManager, PositionDescriptor)
4. EventEmitter

Output is saved to `deployments/hardhat-31337.json`.

## Linting

```bash
# Solidity linting
npm run lint:sol

# TypeScript linting
npm run lint:ts

# Format code
npm run format
```

## Contract Sizes

```bash
npm run size
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
