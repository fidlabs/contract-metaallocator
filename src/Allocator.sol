// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.25;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IAllocator} from "./interfaces/IAllocator.sol";
import {VerifRegAPI} from "filecoin-solidity/contracts/v0.8/VerifRegAPI.sol";
import {VerifRegTypes} from "filecoin-solidity/contracts/v0.8/types/VerifRegTypes.sol";
import {CommonTypes} from "filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {FilAddresses} from "filecoin-solidity/contracts/v0.8/utils/FilAddresses.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/**
 * @title Allocator
 * @notice This contract functions as a middle-man for Allocators. It's made a
 * Verifier (a.k.a. Notary) on Filecoin chain and granted DataCap that can then
 * be granted to Clients. Granting to clients can be done by Allocators that get
 * allowance on the contract, assigned by contract owner.
 * @dev Contract is upgradeable via UUPS by contract owner.
 */
contract Allocator is Initializable, OwnableUpgradeable, UUPSUpgradeable, IAllocator {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /**
     * @notice Enumerable mapping from allocator addresses to their current
     * allowance
     */
    EnumerableMap.AddressToUintMap private _allocators;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Contract initializator. Should be called during deployment.
     * @param initialOwner Initial contract owner
     */
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    /**
     * @dev Internal. Used by Upgrades logic to check if upgrade is authorized.
     * @dev Will revert (reject upgrade) if upgrade isn't called by contract owner.
     */
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice Get allowance of an allocator
     * @param allocator Allocator to get allowance for
     * @return allowance_ Allocator's allowance
     */
    function allowance(address allocator) public view returns (uint256 allowance_) {
        (, allowance_) = _allocators.tryGet(allocator);
    }

    /**
     * @notice Add allowance to Allocator
     * @param allocator Allocator that will receive allowance
     * @param amount Amount of allowance to add
     * @dev Emits AllowanceChanged event
     * @dev Reverts if not called by contract owner
     * @dev Reverts if trying to add 0 allowance
     */
    function addAllowance(address allocator, uint256 amount) external onlyOwner {
        if (amount == 0) revert AmountEqualZero();
        uint256 allowanceBefore = allowance(allocator);
        _allocators.set(allocator, allowanceBefore + amount);
        emit AllowanceChanged(allocator, allowanceBefore, allowance(allocator));
    }

    /**
     * @notice Set allowance of an Allocator. Can be used to remove allowance.
     * @param allocator Allocator
     * @param amount Amount of allowance to set
     * @dev Emits AllowanceChanged event
     * @dev Reverts if not called by contract owner
     * @dev Reverts if setting to 0 when allocator already has 0 allowance
     */
    function setAllowance(address allocator, uint256 amount) external onlyOwner {
        uint256 allowanceBefore = allowance(allocator);
        if (allowanceBefore == 0 && amount == 0) {
            revert AlreadyZero();
        } else if (amount > 0) {
            _allocators.set(allocator, amount);
        } else if (allowanceBefore > 0 && amount == 0) {
            _allocators.remove(allocator);
        }
        emit AllowanceChanged(allocator, allowanceBefore, allowance(allocator));
    }

    /**
     * @notice Grant allowance to a client.
     * @param clientAddress Filecoin address of the client
     * @param amount Amount of datacap to grant
     * @dev Emits DatacapAllocated event
     * @dev Reverts with InsufficientAllowance if caller doesn't have sufficient allowance
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function addVerifiedClient(bytes calldata clientAddress, uint256 amount) external {
        if (amount == 0) revert AmountEqualZero();
        uint256 allocatorBalance = allowance(msg.sender);
        if (allocatorBalance < amount) revert InsufficientAllowance();
        if (allocatorBalance - amount == 0) {
            _allocators.remove(msg.sender);
        } else {
            _allocators.set(msg.sender, allocatorBalance - amount);
        }
        emit DatacapAllocated(msg.sender, clientAddress, amount);
        VerifRegTypes.AddVerifiedClientParams memory params = VerifRegTypes.AddVerifiedClientParams({
            addr: FilAddresses.fromBytes(clientAddress),
            allowance: CommonTypes.BigInt(abi.encodePacked(amount), false)
        });
        VerifRegAPI.addVerifiedClient(params);
    }

    /**
     * @notice Get all allocators with non-zero allowance
     * @return allocators List of allocators with non-zero allowance
     */
    function getAllocators() external view returns (address[] memory allocators) {
        return _allocators.keys();
    }
}
