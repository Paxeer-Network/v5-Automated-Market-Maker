<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# Paxeer Network Deployment

## Network Configuration

| Property | Value |
|----------|-------|
| Network | Paxeer Mainnet |
| Chain ID | 125 |
| RPC | https://public-rpc.paxeer.app/rpc |
| Explorer | https://paxscan.io |
| Currency | PAX |

## Prerequisites

1. Create a `.env` file from the example:
```bash
cp .env.example .env
```

2. Set your deployer private key in `.env`:
```
PRIVATE_KEY=0x...your_private_key
```

3. Ensure your deployer wallet has PAX for gas.

## Deploy

```bash
# Deploy all contracts
npm run deploy:paxeer
```

This deploys the full protocol stack:
- Diamond proxy + 12 facets
- Periphery contracts
- InitDiamond initialization

## Deploy EventEmitter

```bash
npx hardhat run scripts/deploy-event-emitter.ts --network paxeer-network
```

## Upgrade Facets

To upgrade existing facets with new bytecode:

```bash
npx hardhat run scripts/upgrade-facets.ts --network paxeer-network
```

## Verify on Paxscan

```bash
# Verify Diamond
npx hardhat verify --network paxeer-network DIAMOND_ADDRESS OWNER_ADDRESS DIAMONDCUT_ADDRESS

# Verify facets (no constructor args)
npx hardhat verify --network paxeer-network FACET_ADDRESS

# Verify periphery (1 constructor arg: diamond address)
npx hardhat verify --network paxeer-network PERIPHERY_ADDRESS DIAMOND_ADDRESS

# Verify EventEmitter
npx hardhat verify --network paxeer-network EMITTER_ADDRESS DIAMOND_ADDRESS
```

## Live Testing

Run the full live test suite against the deployed Diamond:

```bash
npx hardhat run scripts/paxeer-test.ts --network paxeer-network
```

Tests cover:
- Diamond facet verification
- Permissionless pool creation
- Pool initialization
- Liquidity add/remove
- Bidirectional swaps
- Fee accumulation and collection
- EventEmitter integration

## Deployed Addresses

See `deployments/paxeer-network-125.json` for all current addresses.

| Contract | Address |
|----------|---------|
| Diamond | 0x9595a92d63884d2D9924e0002D45C34d717DB291 |
| PoolFacet | 0x5C8f4B01467894C7EEC0f57994bE672e317c66d2 |
| SwapFacet | 0xf0E343F0185E5896914621f3E583A723A8C02020 |
| LiquidityFacet | 0xb90ED04e330aa93b8D2c6A19343d98B77cFad9CC |
| FeeFacet | 0x63D13c9FB4C4c2e05fE5265B3a266C47cc49136b |
| OracleFacet | 0xF7595F653d1960BaeD00D54a6f064357C366fba9 |
| OraclePegFacet | 0xe7Dc930B5D7a439B2bf161B01a03D4fc5184Ff1d |
| OrderFacet | 0xfDdf08D5D2CB2d6Ac52ca6b92616651d4921Cf9f |
| RewardFacet | 0x3eA125C4B662f2D148f40E736B8816D4574Ce0DB |
| FlashLoanFacet | 0x64404C575eB9ED3BB9afF71dD478236B98272c80 |
| EventEmitter | 0x3FCa66c12B99e395619EE4d0aeabC2339F97E1FF |
| Router | 0x635aC031f7d26035FCc8b138b0835fec0cf6b8AA |
| Quoter | 0x2092D242Cc5d3673D1644128DBd4D199dE51266e |
| PositionManager | 0x8f60EcD67Ef9aF953Dfc1a94F03C1D7e4363e092 |
| OrderManager | 0xB6430A1A4373C14Fa359b242713fBeB4BF2559A4 |
| PositionDescriptor | 0x1862568535F98429aA26B8806E715468754C3418 |

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
