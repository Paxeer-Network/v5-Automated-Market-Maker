// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

/// @title Multicall — Batch multiple calls in one transaction
/// @notice Enables calling multiple functions on the inheriting contract in a single tx
/// @dev Custom implementation — no external dependencies
abstract contract Multicall {
    error MulticallFailed(uint256 index, bytes reason);

    /// @notice Execute multiple calls in a single transaction
    /// @param data Array of encoded function calls
    /// @return results Array of return data from each call
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            if (!success) {
                if (result.length > 0) {
                    revert MulticallFailed(i, result);
                } else {
                    revert MulticallFailed(i, "");
                }
            }
            results[i] = result;
        }
    }

    /// @notice Execute multiple calls, allowing some to fail
    /// @param data Array of encoded function calls
    /// @return successes Array of success flags
    /// @return results Array of return data
    function tryMulticall(
        bytes[] calldata data
    ) external payable returns (bool[] memory successes, bytes[] memory results) {
        successes = new bool[](data.length);
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            successes[i] = success;
            results[i] = result;
        }
    }
}
