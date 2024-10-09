// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {CommonTypes} from "filecoin-project-filecoin-solidity/v0.8/types/CommonTypes.sol";

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
    // 0xb4c030fb
    error NotAllowedSP(CommonTypes.FilActorId provider);

    /// @dev Error thrown when operator_data length is invalid
    // 0x5e9b2d53
    error InvalidOperatorData();

    /// @dev Error thrown when allocation request length is invalid
    // 0x46ac3f35
    error InvalidAllocationRequest();

    /// @dev Error thrown when amount is invalid
    // 0x2c5211c6
    error InvalidAmount();

    /// @dev Thrown if trying to call disabled function
    // 0xbf241488
    error FunctionDisabled();

    /// @dev Thrown if trying to decrease allowance when it's already 0
    // 0x5657d5eb
    error AlreadyZero();

    /// @dev Thrown if trying to give too much datacap to single SP
    // 0xa69a2fd5
    error UnfairDistribution(uint256 maxPerSp, uint256 providedToSingleSp);

    /// @dev Thrown if trying to receive ussuported token type
    // 0xc6de466a
    error UnsupportedType();

    /// @dev Thrown if trying to receive invalid token
    // 0x6d5f86d5
    error InvalidTokenReceived();

    /// @dev Thrown if trying to receive unsupported token
    // 0x6a172882
    error UnsupportedToken();

    /// @dev Thrown if caller is invalid
    // 0x6a172882
    error InvalidCaller(address caller, address expectedCaller);

    /// @dev Datacap transfer failed
    // 0x90b8ec18
    error TransferFailed();

    /// @dev GetClaims call to VerifReg failed
    // 0x9359037c
    error GetClaimsCallFailed();

    /// @dev Error thrown when claim extension request length is invalid
    // 0x2edb7542
    error InvalidClaimExtensionRequest();
}
