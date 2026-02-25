// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title IDiamond — Events and errors emitted by the Diamond proxy
/// @notice Custom EIP-2535 implementation — no external dependencies
interface IDiamond {
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
}
