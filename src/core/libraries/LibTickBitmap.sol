// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../storage/AppStorage.sol";

/// @title LibTickBitmap — Packed tick initialization bitmap for efficient tick traversal
/// @notice Tracks which ticks are initialized (have non-zero liquidityGross)
/// @dev Each word (uint256) stores 256 tick flags. Custom implementation — no external dependencies.
library LibTickBitmap {
    /// @notice Computes the word position and bit position within that word for a given tick
    /// @param tick The tick to compute the position for
    /// @return wordPos The position of the word in the mapping
    /// @return bitPos The bit position within that word (0..255)
    function position(int24 tick) internal pure returns (int16 wordPos, uint8 bitPos) {
        wordPos = int16(tick >> 8);
        bitPos = uint8(int8(tick % 256));
    }

    /// @notice Sets the bit for a tick in the bitmap
    /// @param poolId The pool identifier
    /// @param tick The tick to set
    function set(bytes32 poolId, int24 tick) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        (int16 wordPos, uint8 bitPos) = position(tick);
        uint256 mask = 1 << bitPos;
        s.tickBitmaps[poolId][wordPos] |= mask;
    }

    /// @notice Clears the bit for a tick in the bitmap
    /// @param poolId The pool identifier
    /// @param tick The tick to clear
    function clear(bytes32 poolId, int24 tick) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        (int16 wordPos, uint8 bitPos) = position(tick);
        uint256 mask = 1 << bitPos;
        s.tickBitmaps[poolId][wordPos] &= ~mask;
    }

    /// @notice Checks if a tick is initialized
    /// @param poolId The pool identifier
    /// @param tick The tick to check
    /// @return Whether the tick is initialized
    function isInitialized(bytes32 poolId, int24 tick) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();
        (int16 wordPos, uint8 bitPos) = position(tick);
        return (s.tickBitmaps[poolId][wordPos] & (1 << bitPos)) != 0;
    }

    /// @notice Finds the next initialized tick in the given direction
    /// @dev Searches within the current word first, then moves to adjacent words
    /// @param poolId The pool identifier
    /// @param tick The current tick (exclusive — search starts from tick+1 or tick-1)
    /// @param lte If true, search leftward (decreasing ticks); if false, search rightward
    /// @return next The next initialized tick (or word boundary if none found)
    /// @return initialized Whether an initialized tick was found
    function nextInitializedTickWithinOneWord(
        bytes32 poolId,
        int24 tick,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (lte) {
            // Search leftward (decreasing ticks)
            (int16 wordPos, uint8 bitPos) = position(tick);
            // Mask all bits at and below bitPos
            uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
            uint256 masked = s.tickBitmaps[poolId][wordPos] & mask;

            initialized = masked != 0;
            if (initialized) {
                // Find the most significant bit (highest set bit at or below bitPos)
                next = (int24(wordPos) * 256) + int24(uint24(_mostSignificantBit(masked)));
            } else {
                // No initialized tick in this word at or below bitPos
                next = (int24(wordPos) * 256);
            }
        } else {
            // Search rightward (increasing ticks)
            (int16 wordPos, uint8 bitPos) = position(tick + 1);
            // Mask all bits above and including bitPos
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = s.tickBitmaps[poolId][wordPos] & mask;

            initialized = masked != 0;
            if (initialized) {
                // Find the least significant bit (lowest set bit at or above bitPos)
                next = (int24(wordPos) * 256) + int24(uint24(_leastSignificantBit(masked)));
            } else {
                // No initialized tick in this word at or above bitPos
                next = (int24(wordPos) * 256) + 255;
            }
        }
    }

    /// @dev Finds the most significant bit (index of the highest set bit)
    function _mostSignificantBit(uint256 x) private pure returns (uint8 r) {
        require(x > 0, "LibTickBitmap: zero");
        if (x >= 0x100000000000000000000000000000000) {
            x >>= 128;
            r += 128;
        }
        if (x >= 0x10000000000000000) {
            x >>= 64;
            r += 64;
        }
        if (x >= 0x100000000) {
            x >>= 32;
            r += 32;
        }
        if (x >= 0x10000) {
            x >>= 16;
            r += 16;
        }
        if (x >= 0x100) {
            x >>= 8;
            r += 8;
        }
        if (x >= 0x10) {
            x >>= 4;
            r += 4;
        }
        if (x >= 0x4) {
            x >>= 2;
            r += 2;
        }
        if (x >= 0x2) r += 1;
    }

    /// @dev Finds the least significant bit (index of the lowest set bit)
    function _leastSignificantBit(uint256 x) private pure returns (uint8 r) {
        require(x > 0, "LibTickBitmap: zero");
        r = 255;
        if (x & type(uint128).max > 0) {
            r -= 128;
        } else {
            x >>= 128;
        }
        if (x & type(uint64).max > 0) {
            r -= 64;
        } else {
            x >>= 64;
        }
        if (x & type(uint32).max > 0) {
            r -= 32;
        } else {
            x >>= 32;
        }
        if (x & type(uint16).max > 0) {
            r -= 16;
        } else {
            x >>= 16;
        }
        if (x & type(uint8).max > 0) {
            r -= 8;
        } else {
            x >>= 8;
        }
        if (x & 0xf > 0) {
            r -= 4;
        } else {
            x >>= 4;
        }
        if (x & 0x3 > 0) {
            r -= 2;
        } else {
            x >>= 2;
        }
        if (x & 0x1 > 0) r -= 1;
    }
}
