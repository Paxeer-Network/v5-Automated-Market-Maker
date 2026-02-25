// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title IERC20Permit - EIP-2612 Permit Interface
/// @notice Custom implementation — no external dependencies
interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function nonces(address owner) external view returns (uint256);

    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
