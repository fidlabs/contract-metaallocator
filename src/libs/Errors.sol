// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

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

    /// @dev Error thrown when provided operator_data SP is not allowed
    // 0x993a32a5
    error NotAllowedSP();

    /// @dev Error thrown when operator_data length is invalid
    // 0x5e9b2d53
    error InvalidOperatorData();

    /// @dev Error thrown when allocation request length is invalid
    // 0x46ac3f35
    error InvalidAllocationRequest();

    /// @dev Error thrown when amount is invalid
    /// 0x2c5211c6
    error InvalidAmount();

    /// @dev Thrown if trying to call disabled function
    /// 0xbf241488
    error FunctionDisabled();

    /// @dev Thrown if trying to decrease allowance when it's already 0
    /// 0x5657d5eb
    error AlreadyZero();
}
