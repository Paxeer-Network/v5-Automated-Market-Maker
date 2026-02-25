// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../interfaces/IERC173.sol";
import "../libraries/LibDiamond.sol";

/// @title OwnershipFacet — Contract ownership management (ERC-173)
/// @notice Allows querying and transferring the diamond's ownership
/// @dev Custom implementation — no external dependencies
contract OwnershipFacet is IERC173 {
    function transferOwnership(address _newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }

    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }
}
