// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {DataCapTypes} from "filecoin-solidity/contracts/v0.8/types/DataCapTypes.sol";
import {CommonTypes} from "filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";

interface IClient {
    /**
     * @notice Emitted when the list of allowed storage providers is changed.
     * @param client The address of the client for whom the allowed storage providers are being set
     * @param allowedSPs The new list of allowed storage providers.
     */
    event SPsAddedForClient(address indexed client, uint64[] allowedSPs);

    /**
     * @notice Emitted when the list of allowed storage providers is changed.
     * @param client Client whose allowance is reduced
     * @param disallowedSPs The new list of allowed storage providers.
     */
    event SPsRemovedForClient(address indexed client, uint64[] disallowedSPs);

    /**
     * @notice Emitted when client's allowance is changed by owner
     * @param client Client whose allowance has changed
     * @param allowanceBefore Allowance before the change
     * @param allowanceAfter Allowance after the change
     */
    event AllowanceChanged(address indexed client, uint256 allowanceBefore, uint256 allowanceAfter);

    /**
     * @notice Emitted when DataCap is allocated to a client.
     * @param allocator The address of the allocator.
     * @param client The Filecoin address of the client.
     * @param amount The amount of DataCap allocated.
     */
    event DatacapAllocated(address indexed allocator, CommonTypes.FilAddress indexed client, CommonTypes.BigInt amount);

    /**
     * @notice This function transfers DataCap tokens from the client to the storage provider
     * @dev This function can only be called by the client
     * @param params The parameters for the transfer
     * @dev Reverts with InsufficientAllowance if caller doesn't have sufficient allowance
     * @dev Reverts with InvalidAmount when parsing amount from BigInt to uint256 failed
     */
    function transfer(DataCapTypes.TransferParams calldata params) external;

    /**
     * @notice Adds storage providers to the allowed list for a specific client.
     * @dev This function can only be called by the owner.
     * @param client The address of the client for whom the allowed storage providers are being set
     * @param allowedSPs_ The list of storage providers to add.
     */
    function addAllowedSPsForClient(address client, uint64[] calldata allowedSPs_) external;

    /**
     * @notice This function removes storage providers from the allowed list for a specific client.
     * @dev This function can only be called by the owner.
     * @param client The address of the client for whom the allowed storage providers are being removed
     * @param allowedSPs_ The list of storage providers to remove.
     */
    function removeAllowedSPsForClient(address client, uint64[] calldata allowedSPs_) external;

    /**
     * @notice Returns the current client address.
     * @param client The address of the client.
     * @return The allowance of the client.
     */
    function allowances(address client) external view returns (uint256);

    /**
     * @notice Checks if a storage provider is allowed for a specific client.
     * @param client The address of the client.
     * @param storageProvider The storage provider to check.
     * @return True if the storage provider is allowed, false otherwise.
     */
    function clientSPs(address client, uint64 storageProvider) external view returns (bool);

    /**
     * @notice Increase client allowance
     * @dev This function can only be called by the owner
     * @param client Client that will receive allowance
     * @param amount Amount of allowance to add
     * @dev Emits AllowanceChanged event
     * @dev Reverts if trying to increase allowance by 0
     */
    function increaseAllowance(address client, uint256 amount) external;

    /**
     * @notice Decrease client allowance
     * @dev This function can only be called by the owner
     * @param client Client whose allowance is reduced
     * @param amount Amount to decrease the allowance
     * @dev Emits AllowanceChanged event
     * @dev Reverts if trying to decrease allowance by 0
     * @dev Reverts if client allowance is already 0
     */
    function decreaseAllowance(address client, uint256 amount) external;
}
