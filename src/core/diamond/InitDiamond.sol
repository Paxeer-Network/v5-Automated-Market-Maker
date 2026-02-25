// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../storage/AppStorage.sol";
import "../libraries/LibDiamond.sol";
import "../interfaces/IERC165.sol";
import "../interfaces/IDiamondCut.sol";
import "../interfaces/IDiamondLoupe.sol";
import "../interfaces/IERC173.sol";

/// @title InitDiamond — Diamond initializer
/// @notice Called once during diamond deployment to set up initial protocol state
/// @dev Custom implementation — no external dependencies
contract InitDiamond {
    AppStorage internal s;

    struct InitArgs {
        address treasury;
        uint256 flashLoanFeeBps;
        uint256 maxOrdersPerPool;
        uint256 defaultOrderTTL;
        uint256 minOrderSize;
        uint256 keeperBountyBps;
        uint256 epochDuration;
        uint256 minSwapsForRebate;
        uint256 maxTradeSizeBps;
    }

    function init(InitArgs calldata args) external {
        // Set up ERC-165 interface support
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        // Initialize AppStorage
        AppStorage storage app = LibAppStorage.appStorage();

        // Protocol configuration
        app.treasury = args.treasury;
        app.flashLoanFeeBps = args.flashLoanFeeBps;

        // Order book defaults
        app.maxOrdersPerPool = args.maxOrdersPerPool;
        app.defaultOrderTTL = args.defaultOrderTTL;
        app.minOrderSize = args.minOrderSize;
        app.keeperBountyBps = args.keeperBountyBps;

        // Position counter starts at 1 (0 is reserved for "no position")
        app.nextPositionId = 1;
        app.nextOrderId = 1;

        // Epoch / reward configuration
        app.epochState.epochDuration = args.epochDuration;
        app.epochState.minSwapsForRebate = args.minSwapsForRebate;
        app.epochState.maxTradeSizeBps = args.maxTradeSizeBps;
        app.epochState.currentEpoch = 1;
        app.epochState.epochStartTime = block.timestamp;

        // Reentrancy guard initial state
        app.reentrancyStatus = 1; // _NOT_ENTERED

        // Not paused by default
        app.paused = false;
    }
}
