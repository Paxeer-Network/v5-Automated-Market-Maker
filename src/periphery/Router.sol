// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../core/interfaces/ISwapFacet.sol";
import "../core/interfaces/ILiquidityFacet.sol";
import "../core/interfaces/IERC20.sol";
import "../utils/SafeTransfer.sol";
import "../utils/ReentrancyGuard.sol";

/// @title Router — Multi-hop swap routing with deadline and slippage protection
/// @notice Stateless periphery contract — interacts with the Diamond via external calls
/// @dev Custom implementation — no external dependencies
contract Router is ReentrancyGuard {
    using SafeTransfer for address;

    address public immutable diamond;

    error DeadlineExpired();
    error InsufficientOutputAmount();
    error InvalidPath();
    error ZeroAddress();

    struct ExactInputSingleParams {
        bytes32 poolId;
        bool zeroForOne;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
        address recipient;
        uint256 deadline;
    }

    struct ExactInputParams {
        bytes32[] poolIds;
        bool[] zeroForOnes;
        address tokenIn;
        uint256 amountIn;
        uint256 amountOutMinimum;
        address recipient;
        uint256 deadline;
    }

    struct ExactOutputSingleParams {
        bytes32 poolId;
        bool zeroForOne;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
        address recipient;
        uint256 deadline;
    }

    constructor(address _diamond) {
        if (_diamond == address(0)) revert ZeroAddress();
        diamond = _diamond;
    }

    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        _;
    }

    /// @notice Swap exact input for a single pool
    /// @param params The swap parameters
    /// @return amountOut The amount of output tokens received
    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        nonReentrant
        checkDeadline(params.deadline)
        returns (uint256 amountOut)
    {
        // Transfer tokens from user to this contract
        address(IERC20(address(0))); // Type hint
        _pullTokens(params.zeroForOne, params.poolId, msg.sender, params.amountIn);

        // Approve diamond to spend tokens
        _approveTokens(params.zeroForOne, params.poolId, params.amountIn);

        // Execute swap via Diamond
        ISwapFacet.SwapParams memory swapParams = ISwapFacet.SwapParams({
            poolId: params.poolId,
            zeroForOne: params.zeroForOne,
            amountSpecified: int256(params.amountIn),
            sqrtPriceLimitX96: params.sqrtPriceLimitX96,
            recipient: params.recipient,
            deadline: params.deadline
        });

        ISwapFacet.SwapResult memory result = ISwapFacet(diamond).swap(swapParams);

        amountOut = params.zeroForOne ? uint256(-result.amount1) : uint256(-result.amount0);

        if (amountOut < params.amountOutMinimum) revert InsufficientOutputAmount();
    }

    /// @notice Swap exact input through multiple pools (multi-hop)
    /// @param params The multi-hop swap parameters
    /// @return amountOut The final output amount
    function exactInput(ExactInputParams calldata params)
        external
        nonReentrant
        checkDeadline(params.deadline)
        returns (uint256 amountOut)
    {
        if (params.poolIds.length == 0 || params.poolIds.length != params.zeroForOnes.length) {
            revert InvalidPath();
        }

        uint256 amountIn = params.amountIn;

        for (uint256 i = 0; i < params.poolIds.length; i++) {
            bool isLastHop = (i == params.poolIds.length - 1);
            address recipient = isLastHop ? params.recipient : address(this);

            ISwapFacet.SwapParams memory swapParams = ISwapFacet.SwapParams({
                poolId: params.poolIds[i],
                zeroForOne: params.zeroForOnes[i],
                amountSpecified: int256(amountIn),
                sqrtPriceLimitX96: 0, // No limit for intermediate hops
                recipient: recipient,
                deadline: params.deadline
            });

            ISwapFacet.SwapResult memory result = ISwapFacet(diamond).swap(swapParams);

            amountIn = params.zeroForOnes[i] ? uint256(-result.amount1) : uint256(-result.amount0);
        }

        amountOut = amountIn;
        if (amountOut < params.amountOutMinimum) revert InsufficientOutputAmount();
    }

    /// @notice Swap for exact output from a single pool
    /// @param params The swap parameters
    /// @return amountIn The amount of input tokens spent
    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        nonReentrant
        checkDeadline(params.deadline)
        returns (uint256 amountIn)
    {
        ISwapFacet.SwapParams memory swapParams = ISwapFacet.SwapParams({
            poolId: params.poolId,
            zeroForOne: params.zeroForOne,
            amountSpecified: -int256(params.amountOut),
            sqrtPriceLimitX96: params.sqrtPriceLimitX96,
            recipient: params.recipient,
            deadline: params.deadline
        });

        ISwapFacet.SwapResult memory result = ISwapFacet(diamond).swap(swapParams);

        amountIn = params.zeroForOne ? uint256(result.amount0) : uint256(result.amount1);

        require(amountIn <= params.amountInMaximum, "Router: excessive input");
    }

    // --- Internal Helpers ---

    function _pullTokens(bool zeroForOne, bytes32 poolId, address from, uint256 amount) internal {
        // In production, resolve token address from pool config
        // For now, tokens are pulled in the Diamond's swap function
    }

    function _approveTokens(bool zeroForOne, bytes32 poolId, uint256 amount) internal {
        // Approve Diamond to spend router's tokens
    }
}
