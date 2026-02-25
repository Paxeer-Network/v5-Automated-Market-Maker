// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title IASAMMOracle — External oracle interface for pegged pools
/// @notice Any oracle adapter must implement this to anchor pool prices
/// @dev Provides both spot and TWAP pricing with staleness detection
interface IASAMMOracle {
    /// @notice Get the current spot price from the oracle
    /// @return price The spot price (18 decimals)
    /// @return updatedAt The timestamp of the last update
    function spotPrice() external view returns (uint256 price, uint256 updatedAt);

    /// @notice Get the TWAP price over a given period
    /// @param period The lookback period in seconds
    /// @return price The time-weighted average price (18 decimals)
    function twapPrice(uint32 period) external view returns (uint256 price);
}
