// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "./IDiamond.sol";

/// @title IDiamondCut — Interface for adding/replacing/removing facets
/// @notice Custom EIP-2535 implementation — no external dependencies
interface IDiamondCut is IDiamond {
    /// @notice Add/replace/remove any number of functions and optionally execute a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external;
}
