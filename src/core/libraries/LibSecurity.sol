// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../storage/AppStorage.sol";
import "./LibDiamond.sol";

/// @title LibSecurity — Reentrancy guard, pausable, and access control for facets
/// @notice Provides security modifiers that operate on AppStorage
/// @dev Custom implementation — no external dependencies
library LibSecurity {
    uint256 internal constant _NOT_ENTERED = 1;
    uint256 internal constant _ENTERED = 2;

    error ReentrantCall();
    error ProtocolPaused();
    error NotOwner();
    error NotPauseGuardian();

    /// @notice Check and set reentrancy lock
    function nonReentrantBefore() internal {
        AppStorage storage s = LibAppStorage.appStorage();
        if (s.reentrancyStatus == _ENTERED) revert ReentrantCall();
        s.reentrancyStatus = _ENTERED;
    }

    /// @notice Release reentrancy lock
    function nonReentrantAfter() internal {
        AppStorage storage s = LibAppStorage.appStorage();
        s.reentrancyStatus = _NOT_ENTERED;
    }

    /// @notice Require the protocol is not paused
    function requireNotPaused() internal view {
        AppStorage storage s = LibAppStorage.appStorage();
        if (s.paused) revert ProtocolPaused();
    }

    /// @notice Require the caller is the diamond owner
    function requireOwner() internal view {
        LibDiamond.enforceIsContractOwner();
    }

    /// @notice Require the caller is a pause guardian or the owner
    function requirePauseGuardian() internal view {
        AppStorage storage s = LibAppStorage.appStorage();
        if (!s.pauseGuardians[msg.sender] && msg.sender != LibDiamond.contractOwner()) {
            revert NotPauseGuardian();
        }
    }

    /// @notice Pause the protocol
    function pause() internal {
        AppStorage storage s = LibAppStorage.appStorage();
        s.paused = true;
    }

    /// @notice Unpause the protocol
    function unpause() internal {
        AppStorage storage s = LibAppStorage.appStorage();
        s.paused = false;
    }

    /// @notice Add a pause guardian
    function addPauseGuardian(address guardian) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        s.pauseGuardians[guardian] = true;
    }

    /// @notice Remove a pause guardian
    function removePauseGuardian(address guardian) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        s.pauseGuardians[guardian] = false;
    }

    /// @notice Check deadline hasn't passed
    function checkDeadline(uint256 deadline) internal view {
        require(block.timestamp <= deadline, "LibSecurity: deadline expired");
    }
}
