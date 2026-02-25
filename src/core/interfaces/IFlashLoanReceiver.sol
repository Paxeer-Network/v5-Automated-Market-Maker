// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title IFlashLoanReceiver — Callback interface for flash loan receivers
/// @notice Contracts receiving flash loans must implement this interface
interface IFlashLoanReceiver {
    /// @notice Called by the Diamond after transferring flash-loaned tokens
    /// @param token The borrowed token address
    /// @param amount The borrowed amount
    /// @param fee The fee to be repaid on top of the principal
    /// @param data Arbitrary data forwarded from the flash loan call
    /// @return success Must return true if the operation was successful
    function onFlashLoan(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bool success);
}
