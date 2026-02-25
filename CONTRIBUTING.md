<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# Contributing to v5-ASAMM

Thank you for your interest in contributing to the v5-ASAMM protocol. This guide covers the development workflow and standards expected for all contributions.

## Development Setup

1. Clone the repository
2. Install dependencies: `npm install`
3. Copy environment file: `cp .env.example .env`
4. Compile contracts: `npm run compile`
5. Run tests: `npm test`

## Code Standards

- **Solidity**: Version 0.8.27, 4-space indentation, 120-character line limit
- **TypeScript**: 2-space indentation, single quotes, strict mode
- **Comments**: English only, NatSpec on all public functions
- **Testing**: Unit test every public function, fuzz critical math paths

## Commit Convention

This project follows [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(contracts): add sigmoid curve swap math
fix(oracle): correct TWAP staleness check
test(swap): add fuzz tests for edge cases
docs(architecture): update fee distribution diagram
```

## Pull Request Process

1. Branch from `main`: `git checkout -b feat/your-feature`
2. Write tests first
3. Implement the change
4. Confirm all tests pass: `npm test`
5. Run linting: `npm run lint`
6. Open a PR with a clear description of the changes and their motivation

## Security

If you find a vulnerability, do not open a public issue. Report it directly to the security team -- see [SECURITY.md](SECURITY.md).

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