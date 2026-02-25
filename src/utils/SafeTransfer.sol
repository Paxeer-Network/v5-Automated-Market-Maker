// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title SafeTransfer — Safe ERC-20 transfer wrappers
/// @notice Handles tokens that don't return bool on transfer (e.g., USDT)
/// @dev Custom implementation — no external dependencies
library SafeTransfer {
    error TransferFailed();
    error TransferFromFailed();
    error ApproveFailed();

    /// @notice Safely transfers ERC-20 tokens
    /// @param token The token address
    /// @param to The recipient
    /// @param amount The transfer amount
    function safeTransfer(address token, address to, uint256 amount) internal {
        bool success;
        assembly {
            let freeMemoryPointer := mload(0x40)

            // transfer(address,uint256) selector = 0xa9059cbb
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(freeMemoryPointer, 36), amount)

            success := and(
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }
        if (!success) revert TransferFailed();
    }

    /// @notice Safely transfers ERC-20 tokens from one address to another
    /// @param token The token address
    /// @param from The sender
    /// @param to The recipient
    /// @param amount The transfer amount
    function safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool success;
        assembly {
            let freeMemoryPointer := mload(0x40)

            // transferFrom(address,address,uint256) selector = 0x23b872dd
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(from, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(freeMemoryPointer, 36), and(to, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(freeMemoryPointer, 68), amount)

            success := and(
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
            )
        }
        if (!success) revert TransferFromFailed();
    }

    /// @notice Safely approves ERC-20 token spending
    /// @param token The token address
    /// @param spender The spender address
    /// @param amount The approval amount
    function safeApprove(address token, address spender, uint256 amount) internal {
        bool success;
        assembly {
            let freeMemoryPointer := mload(0x40)

            // approve(address,uint256) selector = 0x095ea7b3
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), and(spender, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(freeMemoryPointer, 36), amount)

            success := and(
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }
        if (!success) revert ApproveFailed();
    }

    /// @notice Safely transfers native ETH
    /// @param to The recipient
    /// @param amount The amount of ETH
    function safeTransferETH(address to, uint256 amount) internal {
        bool success;
        assembly {
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }
        if (!success) revert TransferFailed();
    }
}
