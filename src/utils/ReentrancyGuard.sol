// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title ReentrancyGuard — Reentrancy protection using status flag
/// @notice Custom implementation — no external dependencies
/// @dev Uses a uint256 status variable (1 = unlocked, 2 = locked)
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = _NOT_ENTERED;
    }
}
