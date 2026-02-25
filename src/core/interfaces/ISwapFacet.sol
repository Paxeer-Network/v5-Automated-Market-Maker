// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title ISwapFacet — Interface for the sigmoid curve swap engine
/// @notice Defines swap parameters and events for the ASAMM swap facet
interface ISwapFacet {
    struct SwapParams {
        bytes32 poolId;
        bool zeroForOne;
        int256 amountSpecified;    // Positive = exact input, negative = exact output
        uint160 sqrtPriceLimitX96; // Price limit for the swap
        address recipient;
        uint256 deadline;
    }

    struct SwapResult {
        int256 amount0;
        int256 amount1;
        uint160 sqrtPriceX96After;
        int24 tickAfter;
        uint128 liquidityAfter;
        uint256 feeAmount;
    }

    event Swap(
        bytes32 indexed poolId,
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick,
        uint256 fee
    );

    /// @notice Execute a swap against a pool using the sigmoid bonding curve
    /// @param params The swap parameters
    /// @return result The swap execution result
    function swap(SwapParams calldata params) external returns (SwapResult memory result);
}
