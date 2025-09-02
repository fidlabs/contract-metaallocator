// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {DataCapTypes} from "filecoin-project-filecoin-solidity/v0.8/types/DataCapTypes.sol";

/**
 * @title Interface for Client contract
 * @notice Definition of core functions and events of the Client contract
 */
interface IClientV1 {
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
     * @param client The address of the client.
     * @param amount The amount of DataCap allocated.
     */
    event DatacapSpent(address indexed client, uint256 amount);

    /**
     * @notice Emitted when client config is changed by manager.
     * @param client The Filecoin address of the client.
     * @param maxDeviation The max allowed deviation from fair distribution of data between SPs.
     */
    event ClientConfigChanged(address indexed client, uint256 maxDeviation);

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
     * @param disallowedSPs_ The list of storage providers to remove.
     */
    function removeAllowedSPsForClient(address client, uint64[] calldata disallowedSPs_) external;

    /**
     * @notice Returns the current client allowance.
     * @param client The address of the client.
     * @return allowance The allowance of the client.
     */
    function allowances(address client) external view returns (uint256 allowance);

    /**
     * @notice Get a set of SPs allowed for given client.
     * @param client The address of the client.
     * @return providers List of allowed providers.
     */
    function clientSPs(address client) external view returns (uint256[] memory providers);

    /**
     * @notice Get max deviation from fair distribution for given client.
     * @param client The address of the client.
     * @return maxDeviationFromFairDistribution Max deviation from fair distribution.
     */
    function clientConfigs(address client) external view returns (uint256 maxDeviationFromFairDistribution);

    /**
     * @notice Get a sum of client allocations.
     * @param client The address of the client.
     * @return allocations The sum of the client allocations.
     */
    function totalAllocations(address client) external view returns (uint256 allocations);

    /**
     * @notice Get a sum of client allocations per SP.
     * @param client The address of the client.
     * @return providers List of providers.
     * @return allocations The sum of the client allocations per SP.
     */
    function clientAllocationsPerSP(address client)
        external
        view
        returns (uint256[] memory providers, uint256[] memory allocations);

    /**
     * @notice This function sets the maximum allowed deviation from a fair
     * distribution of data between storage providers.
     * @dev This function can only be called by the owner
     * @param client The address of the client
     * @param maxDeviation Max allowed deviation. 0 = no slack, DENOMINATOR = 100% (based on total allocations of user)
     * @dev Emits ClientConfigChanged event
     */
    function setClientMaxDeviationFromFairDistribution(address client, uint256 maxDeviation) external;

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

    /**
     * @notice The handle_filecoin_method function is a universal entry point for calls
     * coming from built-in Filecoin actors. Datacap is an FRC-46 Token. Receiving FRC46
     * tokens requires implementing a Receiver Hook:
     * https://github.com/filecoin-project/FIPs/blob/master/FRCs/frc-0046.md#receiver-hook.
     * We use handle_filecoin_method to handle the receiver hook and make sure that the token
     * sent to our contract is freshly minted Datacap and reject all other calls and transfers.
     * @param method Method number
     * @param inputCodec Codec of the payload
     * @param params Params of the call
     * @dev Reverts if caller is not a verifreg
     * @dev Reverts if trying to send a unsupported token type
     * @dev Reverts if trying to receive invalid token
     * @dev Reverts if trying to send a unsupported token
     */
    // solhint-disable func-name-mixedcase
    function handle_filecoin_method(uint64 method, uint64 inputCodec, bytes calldata params)
        external
        view
        returns (uint32 exitCode, uint64 codec, bytes memory data);
}
