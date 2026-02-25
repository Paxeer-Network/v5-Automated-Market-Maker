// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../interfaces/IFlashLoanFacet.sol";
import "../interfaces/IFlashLoanReceiver.sol";
import "../interfaces/IERC20.sol";
import "../libraries/LibSecurity.sol";
import "../libraries/LibTransfer.sol";
import "../storage/AppStorage.sol";
import "../../utils/FullMath.sol";

/// @title FlashLoanFacet — Uncollateralized flash loans
/// @notice Provides flash loans from pool reserves with fee collection
/// @dev Diamond facet — operates on AppStorage via delegatecall
contract FlashLoanFacet is IFlashLoanFacet {
    uint256 internal constant BPS = 10_000;

    /// @inheritdoc IFlashLoanFacet
    function flashLoan(address receiver, address token, uint256 amount, bytes calldata data) external {
        LibSecurity.nonReentrantBefore();
        LibSecurity.requireNotPaused();

        require(amount > 0, "FlashLoanFacet: zero amount");
        require(receiver != address(0), "FlashLoanFacet: zero receiver");

        AppStorage storage s = LibAppStorage.appStorage();
        uint256 fee = getFlashLoanFee(amount);

        // Record balance before
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        require(balanceBefore >= amount, "FlashLoanFacet: insufficient liquidity");

        // Transfer tokens to receiver
        LibTransfer.pushToken(token, receiver, amount);

        // Execute callback
        bool success = IFlashLoanReceiver(receiver).onFlashLoan(token, amount, fee, data);
        require(success, "FlashLoanFacet: callback failed");

        // Verify repayment (principal + fee)
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "FlashLoanFacet: not repaid");

        emit FlashLoan(receiver, token, amount, fee);

        LibSecurity.nonReentrantAfter();
    }

    /// @inheritdoc IFlashLoanFacet
    function getFlashLoanFee(uint256 amount) public view returns (uint256 fee) {
        AppStorage storage s = LibAppStorage.appStorage();
        fee = FullMath.mulDiv(amount, s.flashLoanFeeBps, BPS);
        if (fee == 0 && amount > 0) fee = 1; // Minimum 1 wei fee
    }

    /// @notice Set the flash loan fee (owner only)
    /// @param feeBps Fee in basis points
    function setFlashLoanFee(uint256 feeBps) external {
        LibSecurity.requireOwner();
        require(feeBps <= 100, "FlashLoanFacet: fee too high"); // Max 1%
        AppStorage storage s = LibAppStorage.appStorage();
        s.flashLoanFeeBps = feeBps;
    }
}
