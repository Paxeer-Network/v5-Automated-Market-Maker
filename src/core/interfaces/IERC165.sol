// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title IERC165 - Standard Interface Detection
/// @notice Custom implementation — no external dependencies
interface IERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceId The interface identifier, as specified in ERC-165
    /// @return `true` if the contract implements `interfaceId` and
    ///  `interfaceId` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
