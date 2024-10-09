// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {VerifRegTypes} from "filecoin-project-filecoin-solidity/v0.8/types/VerifRegTypes.sol";
import {DataCapTypes} from "filecoin-project-filecoin-solidity/v0.8/types/DataCapTypes.sol";
import {CommonTypes} from "filecoin-project-filecoin-solidity/v0.8/types/CommonTypes.sol";
import {VerifRegAPI} from "filecoin-project-filecoin-solidity/v0.8/VerifRegAPI.sol";
import {DataCapAPI} from "filecoin-project-filecoin-solidity/v0.8/DataCapAPI.sol";
import {Errors} from "./libs/Errors.sol";
import {CBORDecoder} from "filecoin-project-filecoin-solidity/v0.8/utils/CborDecode.sol";
import {IClient} from "./interfaces/IClient.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {BigInts} from "filecoin-project-filecoin-solidity/v0.8/utils/BigInts.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {UtilsHandlers} from "filecoin-project-filecoin-solidity/v0.8/utils/UtilsHandlers.sol";

/**
 * @title Client
 * @notice The Client contract facilitates the management of DataCap allocations.
 * It enables the allocator to set and modify client allowances, manage
 * lists of authorized storage providers for each client, and define distribution
 * constraints to ensure fair allocation. Clients can transfer their allocated
 * DataCap to permitted storage providers, adhering to the configured allowances
 * and distribution rules.
 */
contract Client is Initializable, IClient, MulticallUpgradeable, Ownable2StepUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToUintMap;

    uint32 private constant _FRC46_TOKEN_TYPE = 2233613279; // method_hash!("FRC46") as u32;
    address private constant _DATACAP_ADDRESS = address(0xfF00000000000000000000000000000000000007);
    uint256 public constant TOKEN_PRECISION = 1e18;
    uint256 public constant DENOMINATOR = 10000;
    mapping(address client => uint256 allowance) public allowances;
    mapping(address client => EnumerableSet.UintSet allowedSPs) internal _clientSPs;

    mapping(address client => uint256 allocations) public totalAllocations;
    mapping(address client => uint256 maxDeviationFromFairDistribution) public clientConfigs;
    mapping(address client => EnumerableMap.UintToUintMap allocations) internal _clientAllocationsPerSP;

    struct ProviderAllocation {
        CommonTypes.FilActorId provider;
        uint64 size;
    }

    struct ProviderClaim {
        CommonTypes.FilActorId provider;
        CommonTypes.FilActorId claim;
    }

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
     * @dev Reverts with UnfairDistribution when trying to give too much to single SP
     */
    function transfer(DataCapTypes.TransferParams calldata params) external {
        int256 exitCode;

        (uint256 tokenAmount, bool failed) = BigInts.toUint256(params.amount);
        if (failed) revert Errors.InvalidAmount();
        uint256 datacapAmount = tokenAmount / TOKEN_PRECISION;
        if (allowances[msg.sender] < datacapAmount) revert Errors.InsufficientAllowance();

        (ProviderAllocation[] memory allocations, ProviderClaim[] memory claimExtensions) =
            _deserializeVerifregOperatorData(params.operator_data);

        _verifyAndRegisterAllocations(allocations);
        _verifyAndRegisterClaimExtensions(claimExtensions);

        allowances[msg.sender] -= datacapAmount;
        emit DatacapSpent(msg.sender, datacapAmount);
        /// @custom:oz-upgrades-unsafe-allow-reachable delegatecall
        (exitCode,) = DataCapAPI.transfer(params);
        if (exitCode != 0) {
            revert Errors.TransferFailed();
        }
    }

    function _verifyAndRegisterAllocations(ProviderAllocation[] memory allocations) internal {
        for (uint256 i = 0; i < allocations.length; i++) {
            ProviderAllocation memory alloc = allocations[i];
            _ensureSPIsAllowed(alloc.provider);
            uint256 size = alloc.size;
            uint64 providerInt = CommonTypes.FilActorId.unwrap(alloc.provider);
            if (_clientAllocationsPerSP[msg.sender].contains(providerInt)) {
                size += _clientAllocationsPerSP[msg.sender].get(providerInt);
            }
            // slither-disable-next-line unused-return
            _clientAllocationsPerSP[msg.sender].set(providerInt, size);
            _ensureMaxDeviationIsNotExceeded(size);
        }
    }

    function _verifyAndRegisterClaimExtensions(ProviderClaim[] memory claimExtensions) internal {
        int256 exitCode;
        uint256 claimProvidersCount = 0;
        CommonTypes.FilActorId[] memory claimProviders = new CommonTypes.FilActorId[](claimExtensions.length);

        // get providers list with no duplicates
        for (uint256 i = 0; i < claimExtensions.length; i++) {
            ProviderClaim memory claim = claimExtensions[i];
            bool alreadyExists = false;
            for (uint256 j = 0; j < claimProvidersCount; j++) {
                if (CommonTypes.FilActorId.unwrap(claimProviders[j]) == CommonTypes.FilActorId.unwrap(claim.provider)) {
                    alreadyExists = true;
                    break;
                }
            }
            if (!alreadyExists) {
                _ensureSPIsAllowed(claim.provider);
                claimProviders[claimProvidersCount++] = claim.provider;
            }
        }

        CommonTypes.FilActorId[] memory claims = new CommonTypes.FilActorId[](claimExtensions.length);
        for (uint256 providerIdx = 0; providerIdx < claimProvidersCount; providerIdx++) {
            // for each provider, find all claims for this provider
            uint256 claimCount = 0;
            CommonTypes.FilActorId provider = claimProviders[providerIdx];
            for (uint256 i = 0; i < claimExtensions.length; i++) {
                ProviderClaim memory claim = claimExtensions[i];
                if (CommonTypes.FilActorId.unwrap(claim.provider) == CommonTypes.FilActorId.unwrap(provider)) {
                    claims[claimCount++] = claim.claim;
                }
            }
            assembly {
                mstore(claims, claimCount)
            }

            // get details of claims of this provider
            VerifRegTypes.GetClaimsParams memory getClaimsParams =
                VerifRegTypes.GetClaimsParams({provider: provider, claim_ids: claims});
            VerifRegTypes.GetClaimsReturn memory claimsDetails;
            (exitCode, claimsDetails) = VerifRegAPI.getClaims(getClaimsParams);
            if (exitCode != 0 || claimsDetails.batch_info.success_count != claims.length) {
                revert Errors.GetClaimsCallFailed();
            }

            // calculate total size of claims (a.k.a. how much datacap is going to this single SP)
            uint256 size = 0;
            for (uint256 i = 0; i < claimsDetails.claims.length; i++) {
                VerifRegTypes.Claim memory claim = claimsDetails.claims[i];
                size += claim.size;
            }
            uint64 providerInt = CommonTypes.FilActorId.unwrap(provider);
            if (_clientAllocationsPerSP[msg.sender].contains(providerInt)) {
                size += _clientAllocationsPerSP[msg.sender].get(providerInt);
            }
            // slither-disable-next-line unused-return
            _clientAllocationsPerSP[msg.sender].set(providerInt, size);
            _ensureMaxDeviationIsNotExceeded(size);
        }
    }

    /**
     * @dev Check if a single SP can get `size` total datacap from a client.
     * @dev Reverts with UnfairDistribution if size is too big
     * @param size Total allocations for a single SP
     */
    function _ensureMaxDeviationIsNotExceeded(uint256 size) internal view {
        uint256 maxSlack = clientConfigs[msg.sender];
        uint256 total = totalAllocations[msg.sender];
        uint256 providersCount = _clientSPs[msg.sender].length();
        uint256 fairMax = total / providersCount;
        uint256 max = fairMax + total * maxSlack / DENOMINATOR;

        if (size > max) revert Errors.UnfairDistribution(max, size);
    }

    /**
     * @notice Get a set of SPs allowed for given client.
     * @param client The address of the client.
     * @return providers List of allowed providers.
     */
    function clientSPs(address client) external view returns (uint256[] memory providers) {
        providers = _clientSPs[client].values();
    }

    /**
     * @notice Get a sum of client allocations per SP.
     * @param client The address of the client.
     * @return providers List of providers for a specific client.
     * @return allocations The sum of the client allocations per SP.
     */
    function clientAllocationsPerSP(address client)
        external
        view
        returns (uint256[] memory providers, uint256[] memory allocations)
    {
        providers = _clientAllocationsPerSP[client].keys();
        allocations = new uint256[](providers.length);

        for (uint256 i = 0; i < providers.length; i++) {
            allocations[i] = _clientAllocationsPerSP[client].get(providers[i]);
        }
    }

    /**
     * @notice This function sets the maximum allowed deviation from a fair
     * distribution of data between storage providers.
     * @dev This function can only be called by the owner
     * @param client The address of the client
     * @param maxDeviation Max allowed deviation. 0 = no slack, DENOMINATOR = 100% (based on total allocations of user)
     * @dev Emits ClientConfigChanged event
     */
    function setClientMaxDeviationFromFairDistribution(address client, uint256 maxDeviation) external onlyOwner {
        clientConfigs[client] = maxDeviation;
        emit ClientConfigChanged(client, maxDeviation);
    }

    /**
     * @notice This function sets the list of allowed storage providers for a specific client
     * @dev This function can only be called by the owner
     * @param client The address of the client for whom the allowed storage providers are being set
     * @param allowedSPs_ The list of allowed storage providers
     */
    function addAllowedSPsForClient(address client, uint64[] calldata allowedSPs_) external onlyOwner {
        for (uint256 i = 0; i < allowedSPs_.length; i++) {
            // slither-disable-next-line unused-return
            _clientSPs[client].add(allowedSPs_[i]);
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
            // slither-disable-next-line unused-return
            _clientSPs[client].remove(disallowedSPs_[i]);
        }
        emit SPsRemovedForClient(client, disallowedSPs_);
    }

    /**
     * @notice Deserialize Verifreg Operator Data
     * @param cborData The cbor encoded operator data
     */
    function _deserializeVerifregOperatorData(bytes memory cborData)
        internal
        pure
        returns (ProviderAllocation[] memory allocations, ProviderClaim[] memory claimExtensions)
    {
        uint256 operatorDataLength;
        uint256 allocationRequestsLength;
        uint256 claimExtensionRequestsLength;
        uint64 provider;
        uint64 claimId;
        uint64 size;
        uint256 byteIdx = 0;

        (operatorDataLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        if (operatorDataLength != 2) revert Errors.InvalidOperatorData();

        (allocationRequestsLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        allocations = new ProviderAllocation[](allocationRequestsLength);
        for (uint256 i = 0; i < allocationRequestsLength; i++) {
            uint256 allocationRequestLength;
            (allocationRequestLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);

            if (allocationRequestLength != 6) {
                revert Errors.InvalidAllocationRequest();
            }

            (provider, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            // slither-disable-start unused-return
            (, byteIdx) = CBORDecoder.readBytes(cborData, byteIdx); // data (CID)
            (size, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            (, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx); // termMin
            (, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx); // termMax
            (, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx); // expiration
            // slither-disable-end unused-return

            allocations[i].provider = CommonTypes.FilActorId.wrap(provider);
            allocations[i].size = size;
        }

        (claimExtensionRequestsLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        claimExtensions = new ProviderClaim[](claimExtensionRequestsLength);
        for (uint256 i = 0; i < claimExtensionRequestsLength; i++) {
            uint256 claimExtensionRequestLength;
            (claimExtensionRequestLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);

            if (claimExtensionRequestLength != 3) {
                revert Errors.InvalidClaimExtensionRequest();
            }

            (provider, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            (claimId, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            // slither-disable-start unused-return
            (, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx); // termMax
            // slither-disable-end unused-return

            claimExtensions[i].provider = CommonTypes.FilActorId.wrap(provider);
            claimExtensions[i].claim = CommonTypes.FilActorId.wrap(claimId);
        }
    }

    /**
     * @notice This function checks if sender is allowed to use given provider
     * @param provider The provider to check
     * @dev Reverts if provider is not allowed
     */
    function _ensureSPIsAllowed(CommonTypes.FilActorId provider) internal view {
        if (!_clientSPs[msg.sender].contains(CommonTypes.FilActorId.unwrap(provider))) {
            revert Errors.NotAllowedSP(provider);
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
        totalAllocations[client] += amount;
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
        totalAllocations[client] -= amount; // FIXME document that this has potentially affected slack
        emit AllowanceChanged(client, allowanceBefore, allowances[client]);
    }

    /**
     * @notice Disable the renounceOwnership function which leaves the contract without an owner.
     * @dev Reverts if trying to call
     */
    function renounceOwnership() public view override onlyOwner {
        revert Errors.FunctionDisabled();
    }

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
     * @dev Reverts if caller is not a datacap contract
     * @dev Reverts if trying to send a unsupported token type
     * @dev Reverts if trying to receive invalid token
     * @dev Reverts if trying to send a unsupported token
     */
    // solhint-disable func-name-mixedcase
    function handle_filecoin_method(uint64 method, uint64 inputCodec, bytes calldata params)
        external
        view
        returns (uint32 exitCode, uint64 codec, bytes memory data)
    {
        if (msg.sender != _DATACAP_ADDRESS) revert Errors.InvalidCaller(msg.sender, _DATACAP_ADDRESS);
        CommonTypes.UniversalReceiverParams memory receiverParams =
            UtilsHandlers.handleFilecoinMethod(method, inputCodec, params);
        if (receiverParams.type_ != _FRC46_TOKEN_TYPE) revert Errors.UnsupportedType();
        (uint256 tokenReceivedLength, uint256 byteIdx) = CBORDecoder.readFixedArray(receiverParams.payload, 0);
        if (tokenReceivedLength != 6) revert Errors.InvalidTokenReceived();
        uint64 from;
        (from, byteIdx) = CBORDecoder.readUInt64(receiverParams.payload, byteIdx); // payload == FRC46TokenReceived
        if (from != CommonTypes.FilActorId.unwrap(DataCapTypes.ActorID)) revert Errors.UnsupportedToken();
        exitCode = 0;
        codec = 0;
        data = "";
    }
}
