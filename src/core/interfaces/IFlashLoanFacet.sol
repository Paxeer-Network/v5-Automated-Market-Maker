// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title IFlashLoanFacet — Interface for flash loan functionality
/// @notice Provides uncollateralized loans that must be repaid within one transaction
interface IFlashLoanFacet {
    event FlashLoan(
        address indexed receiver,
        address indexed token,
        uint256 amount,
        uint256 fee
    );

    /// @notice Execute a flash loan
    /// @param receiver The contract that will receive the tokens and execute the callback
    /// @param token The token to borrow
    /// @param amount The amount to borrow
    /// @param data Arbitrary data passed to the receiver's callback
    function flashLoan(
        address receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external;

    /// @notice Get the flash loan fee for a given amount
    /// @param amount The loan amount
    /// @return fee The fee amount
    function getFlashLoanFee(uint256 amount) external view returns (uint256 fee);
}
