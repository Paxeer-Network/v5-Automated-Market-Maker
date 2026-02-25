// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../core/interfaces/IERC20.sol";
import "../core/interfaces/IERC20Permit.sol";

/// @title SelfPermit — Gasless ERC-20 approvals via EIP-2612
/// @notice Allows users to approve tokens to the calling contract via permit signature
/// @dev Custom implementation — no external dependencies
abstract contract SelfPermit {
    /// @notice Permits this contract to spend the caller's tokens via EIP-2612
    /// @param token The token to permit
    /// @param value The amount to permit
    /// @param deadline The deadline for the permit signature
    /// @param v The v component of the signature
    /// @param r The r component of the signature
    /// @param s The s component of the signature
    function selfPermit(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        IERC20Permit(token).permit(msg.sender, address(this), value, deadline, v, r, s);
    }

    /// @notice Permits this contract to spend the caller's tokens, ignoring failures
    /// @dev Used as a fallback when the token may not support permit or nonce was already used
    function selfPermitIfNecessary(
        address token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        if (IERC20(token).allowance(msg.sender, address(this)) < value) {
            try IERC20Permit(token).permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
        }
    }
}
