<p align="center">
  <img src="https://raw.githubusercontent.com/Paxeer-Network/Paxeer-Network-Brand-Kit/7c7147e2c5349127fb07db139df0333345881524/cdn_paxeer_logo.svg" alt="Paxeer Network" width="200" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/Solidity-0.8.27-363636.svg" alt="Solidity" />
  <img src="https://img.shields.io/badge/Network-Paxeer%20(125)-green.svg" alt="Paxeer" />
</p>

# FlashLoanFacet API Reference

The FlashLoanFacet provides uncollateralized flash loans from pool reserves.

## Functions

### flashLoan

Execute a flash loan. Borrowed tokens must be repaid (plus fee) within the same transaction.

```solidity
function flashLoan(
    address receiver,
    address token,
    uint256 amount,
    bytes calldata data
) external
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| receiver | address | Contract implementing IFlashLoanReceiver |
| token | address | Token to borrow |
| amount | uint256 | Amount to borrow |
| data | bytes | Arbitrary data passed to receiver callback |

**Flow:**
1. Protocol transfers `amount` of `token` to `receiver`
2. Protocol calls `receiver.onFlashLoan(msg.sender, token, amount, fee, data)`
3. Receiver must approve protocol to pull back `amount + fee`
4. Protocol pulls `amount + fee` from receiver

**Reverts if** receiver doesn't repay amount + fee.

### getFlashLoanFee

Get the fee for a flash loan amount.

```solidity
function getFlashLoanFee(uint256 amount) external view returns (uint256 fee)
```

Default fee: 9 bps (0.09%).

## IFlashLoanReceiver Interface

Flash loan receivers must implement:

```solidity
interface IFlashLoanReceiver {
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}
```

Must return `keccak256("IFlashLoanReceiver.onFlashLoan")`.

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
