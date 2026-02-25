// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title IERC173 - Contract Ownership Standard
/// @notice Custom implementation — no external dependencies
interface IERC173 {
    /// @notice Emitted when ownership is transferred
    /// @param previousOwner The previous owner address
    /// @param newOwner The new owner address
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Get the address of the owner
    /// @return owner_ The address of the owner
    function owner() external view returns (address owner_);

    /// @notice Set the address of the new owner of the contract
    /// @dev Set _newOwner to address(0) to renounce any ownership
    /// @param _newOwner The address of the new owner of the contract
    function transferOwnership(address _newOwner) external;
}
