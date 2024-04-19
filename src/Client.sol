// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {DataCapTypes} from "filecoin-solidity/contracts/v0.8/types/DataCapTypes.sol";
import {DataCapAPI} from "filecoin-solidity/contracts/v0.8/DataCapAPI.sol";
import {Errors} from "./libs/Errors.sol";
import {CBORDecoder} from "filecoin-solidity/contracts/v0.8/utils/CborDecode.sol";
import {IClient} from "./interfaces/IClient.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {BigInts} from "filecoin-solidity/contracts/v0.8/utils/BigInts.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

contract Client is Initializable, IClient, MulticallUpgradeable, Ownable2StepUpgradeable {
    mapping(address client => uint256 allowance) public allowances;
    mapping(address client => mapping(uint64 storageProvider => bool allowedSP) allowedSPs) public clientSPs;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
    }

    /**
     * @notice This function transfers DataCap tokens from the client to the storage provider
     * @dev This function can only be called by the client
     * @param params The parameters for the transfer
     * @dev Reverts with InsufficientAllowance if caller doesn't have sufficient allowance
     * @dev Reverts with InvalidAmount when parsing amount from BigInt to uint256 failed
     */
    function transfer(DataCapTypes.TransferParams calldata params) external {
        (uint256 parsedAmount, bool failed) = BigInts.toUint256(params.amount);
        if (failed) revert Errors.InvalidAmount();
        if (allowances[msg.sender] < parsedAmount) revert Errors.InsufficientAllowance();
        uint64[] memory providers = _deserializeAllocationRequests(params.operator_data);
        _ensureSPsAreAllowed(providers);
        allowances[msg.sender] -= parsedAmount;
        /// @custom:oz-upgrades-unsafe-allow-reachable delegatecall
        DataCapAPI.transfer(params);
        emit DatacapAllocated(msg.sender, params.to, params.amount);
    }

    /**
     * @notice This function sets the list of allowed storage providers for a specific client
     * @dev This function can only be called by the owner
     * @param client The address of the client for whom the allowed storage providers are being set
     * @param allowedSPs_ The list of allowed storage providers
     */
    function addAllowedSPsForClient(address client, uint64[] calldata allowedSPs_) external onlyOwner {
        for (uint256 i = 0; i < allowedSPs_.length; i++) {
            clientSPs[client][allowedSPs_[i]] = true;
        }
        emit SPsAddedForClient(client, allowedSPs_);
    }

    /**
     * @notice This function removes storage providers from the allowed list for a specific client
     * @dev This function can only be called by the owner
     * @param client The address of the client for whom the allowed storage providers are being removed
     * @param disallowedSPs_ The list of storage providers to remove
     */
    function removeAllowedSPsForClient(address client, uint64[] calldata disallowedSPs_) external onlyOwner {
        for (uint256 i = 0; i < disallowedSPs_.length; i++) {
            clientSPs[client][disallowedSPs_[i]] = false;
        }
        emit SPsRemovedForClient(client, disallowedSPs_);
    }

    /**
     * @notice This function reads the array of AllocationRequests from the operator data and returns the providers
     * @param cborData The cbor encoded operator data
     * @dev byteIdx The index of the byte to start reading from
     */
    function _deserializeAllocationRequests(bytes memory cborData) internal pure returns (uint64[] memory providers) {
        uint256 operatorDataLength;
        uint256 allocationRequestsLength;
        uint64 provider;
        uint256 byteIdx = 0;

        (operatorDataLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        if (operatorDataLength != 2) revert Errors.InvalidOperatorData();

        (allocationRequestsLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);

        providers = new uint64[](allocationRequestsLength);

        for (uint256 i = 0; i < operatorDataLength; i++) {
            uint256 allocationRequestLength;
            (allocationRequestLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);

            if (allocationRequestLength != 6) {
                revert Errors.InvalidAllocationRequest();
            }

            (provider, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            providers[i] = provider;

            (, byteIdx) = CBORDecoder.readBytes(cborData, byteIdx);
            (, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            (, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx);
            (, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx);
            (, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx);
        }
    }

    /**
     * @notice This function matches the providers with the allowedSPs
     * @param providers The providers list to match
     * @dev Reverts if providers do not match client SPs
     */
    function _ensureSPsAreAllowed(uint64[] memory providers) internal view {
        for (uint256 i = 0; i < providers.length; i++) {
            if (!clientSPs[msg.sender][providers[i]]) {
                revert Errors.NotAllowedSP();
            }
        }
    }

    /**
     * @notice Increase client allowance
     * @dev This function can only be called by the owner
     * @param client Client that will receive allowance
     * @param amount Amount of allowance to add
     * @dev Emits AllowanceChanged event
     * @dev Reverts if trying to increase allowance by 0
     */
    function increaseAllowance(address client, uint256 amount) external onlyOwner {
        if (amount == 0) revert Errors.AmountEqualZero();
        uint256 allowanceBefore = allowances[client];
        allowances[client] += amount;
        emit AllowanceChanged(client, allowanceBefore, allowances[client]);
    }

    /**
     * @notice Decrease client allowance
     * @dev This function can only be called by the owner
     * @param client Client whose allowance is reduced
     * @param amount Amount to decrease the allowance
     * @dev Emits AllowanceChanged event
     * @dev Reverts if trying to decrease allowance by 0
     * @dev Reverts if client allowance is already 0
     */
    function decreaseAllowance(address client, uint256 amount) external onlyOwner {
        if (amount == 0) revert Errors.AmountEqualZero();
        uint256 allowanceBefore = allowances[client];
        if (allowanceBefore == 0) {
            revert Errors.AlreadyZero();
        } else if (allowanceBefore < amount) {
            amount = allowanceBefore;
        }
        allowances[client] -= amount;
        emit AllowanceChanged(client, allowanceBefore, allowances[client]);
    }

    function renounceOwnership() public view override onlyOwner {
        revert Errors.FunctionDisabled();
    }
}
