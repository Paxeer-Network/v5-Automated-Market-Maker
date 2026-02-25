// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../../utils/SafeTransfer.sol";
import "../interfaces/IERC20.sol";

/// @title LibTransfer — Token transfer helpers for facets
/// @notice Wraps SafeTransfer with balance-check patterns used across facets
/// @dev Custom implementation — no external dependencies
library LibTransfer {
    using SafeTransfer for address;

    error InsufficientTokenBalance();
    error TransferAmountExceedsBalance();

    /// @notice Transfer tokens from sender to the diamond (pull pattern)
    /// @param token The ERC-20 token address
    /// @param from The sender address
    /// @param amount The amount to transfer
    function pullToken(address token, address from, uint256 amount) internal {
        if (amount == 0) return;
        token.safeTransferFrom(from, address(this), amount);
    }

    /// @notice Transfer tokens from the diamond to a recipient (push pattern)
    /// @param token The ERC-20 token address
    /// @param to The recipient address
    /// @param amount The amount to transfer
    function pushToken(address token, address to, uint256 amount) internal {
        if (amount == 0) return;
        token.safeTransfer(to, amount);
    }

    /// @notice Get the diamond's token balance
    /// @param token The ERC-20 token address
    /// @return balance The token balance
    function getBalance(address token) internal view returns (uint256 balance) {
        balance = IERC20(token).balanceOf(address(this));
    }

    /// @notice Transfer tokens with balance verification
    /// @dev Checks that the diamond actually received the expected amount (handles fee-on-transfer tokens)
    /// @param token The ERC-20 token address
    /// @param from The sender address
    /// @param amount The expected amount
    /// @return actualAmount The actual amount received
    function pullTokenWithBalanceCheck(
        address token,
        address from,
        uint256 amount
    ) internal returns (uint256 actualAmount) {
        uint256 balanceBefore = getBalance(token);
        pullToken(token, from, amount);
        uint256 balanceAfter = getBalance(token);
        actualAmount = balanceAfter - balanceBefore;
    }

    /// @notice Transfer ETH to a recipient
    /// @param to The recipient address
    /// @param amount The amount of ETH
    function pushETH(address to, uint256 amount) internal {
        if (amount == 0) return;
        SafeTransfer.safeTransferETH(to, amount);
    }
}
