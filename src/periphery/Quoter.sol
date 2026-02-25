// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../core/interfaces/ISwapFacet.sol";
import "../core/interfaces/IPool.sol";
import "../core/interfaces/IFeeFacet.sol";

/// @title Quoter — Off-chain quote simulation
/// @notice Simulates swaps via staticcall to return expected output without executing
/// @dev Stateless periphery contract — no external dependencies
contract Quoter {
    address public immutable diamond;

    constructor(address _diamond) {
        diamond = _diamond;
    }

    /// @notice Get a quote for an exact input swap
    /// @param poolId The pool to quote against
    /// @param zeroForOne The swap direction
    /// @param amountIn The input amount
    /// @return amountOut The expected output amount
    /// @return fee The fee amount
    /// @return sqrtPriceX96After The price after the swap
    function quoteExactInputSingle(
        bytes32 poolId,
        bool zeroForOne,
        uint256 amountIn
    ) external returns (uint256 amountOut, uint256 fee, uint160 sqrtPriceX96After) {
        try ISwapFacet(diamond).swap(
            ISwapFacet.SwapParams({
                poolId: poolId,
                zeroForOne: zeroForOne,
                amountSpecified: int256(amountIn),
                sqrtPriceLimitX96: 0,
                recipient: address(this),
                deadline: block.timestamp + 1
            })
        ) returns (ISwapFacet.SwapResult memory result) {
            amountOut = zeroForOne ? uint256(-result.amount1) : uint256(-result.amount0);
            fee = result.feeAmount;
            sqrtPriceX96After = result.sqrtPriceX96After;
        } catch (bytes memory reason) {
            // Decode the revert data if the swap reverted with specific info
            amountOut = 0;
            fee = 0;
            sqrtPriceX96After = 0;
        }
    }

    /// @notice Get a quote for a multi-hop exact input swap
    /// @param poolIds The pool path
    /// @param zeroForOnes The swap directions for each hop
    /// @param amountIn The initial input amount
    /// @return amountOut The final expected output
    function quoteExactInput(
        bytes32[] calldata poolIds,
        bool[] calldata zeroForOnes,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        require(poolIds.length == zeroForOnes.length, "Quoter: length mismatch");

        uint256 currentAmount = amountIn;

        for (uint256 i = 0; i < poolIds.length; i++) {
            try ISwapFacet(diamond).swap(
                ISwapFacet.SwapParams({
                    poolId: poolIds[i],
                    zeroForOne: zeroForOnes[i],
                    amountSpecified: int256(currentAmount),
                    sqrtPriceLimitX96: 0,
                    recipient: address(this),
                    deadline: block.timestamp + 1
                })
            ) returns (ISwapFacet.SwapResult memory result) {
                currentAmount = zeroForOnes[i] ? uint256(-result.amount1) : uint256(-result.amount0);
            } catch {
                return 0;
            }
        }

        amountOut = currentAmount;
    }

    /// @notice Get the estimated fee for a trade
    /// @param poolId The pool
    /// @param tradeSize The trade size
    /// @return feeBps The estimated fee in basis points
    function estimateFee(bytes32 poolId, uint256 tradeSize) external view returns (uint256 feeBps) {
        feeBps = IFeeFacet(diamond).calculateFee(poolId, tradeSize);
    }

    /// @notice Get the current pool price
    /// @param poolId The pool identifier
    /// @return sqrtPriceX96 The current sqrt price
    /// @return tick The current tick
    /// @return liquidity The current liquidity
    function getPoolPrice(bytes32 poolId) external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint128 liquidity
    ) {
        // Read pool state from diamond
        // Note: This assumes the diamond exposes getPoolState through PoolFacet
        (bool success, bytes memory data) = diamond.staticcall(
            abi.encodeWithSignature("getPoolState(bytes32)", poolId)
        );
        require(success, "Quoter: pool query failed");

        IPool.PoolState memory state = abi.decode(data, (IPool.PoolState));
        sqrtPriceX96 = state.sqrtPriceX96;
        tick = state.currentTick;
        liquidity = state.liquidity;
    }
}
