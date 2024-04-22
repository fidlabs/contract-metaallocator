// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

library Errors {
    /// @dev Error thrown when caller is not the manager
    // 0xc0fc8a8a
    error NotManager();

    /// @dev Error thrown when caller is not the client
    // 0x20dbc874
    error NotClient();

    /// @dev Error thrown when senders balance is less than his allowance
    // 0x13be252b
    error InsufficientAllowance();

    /// @dev Error thrown when amount is equal to zero
    // 0xb0da7f34
    error AmountEqualZero();
}
