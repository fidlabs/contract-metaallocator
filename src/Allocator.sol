// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.25;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IAllocator} from "./interfaces/IAllocator.sol";
import {VerifRegAPI} from "filecoin-solidity/contracts/v0.8/VerifRegAPI.sol";
import {VerifRegTypes} from "filecoin-solidity/contracts/v0.8/types/VerifRegTypes.sol";
import {CommonTypes} from "filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {FilAddresses} from "filecoin-solidity/contracts/v0.8/utils/FilAddresses.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract Allocator is Initializable, OwnableUpgradeable, UUPSUpgradeable, IAllocator {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    EnumerableMap.AddressToUintMap private _allocators;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function allowance(address allocator) public view returns (uint256) {
        return _allocators.contains(allocator) ? _allocators.get(allocator) : 0;
    }

    function addAllowance(address allocatorAddress, uint256 amount) external onlyOwner {
        if (amount == 0) revert AmountEqualZero();
        uint256 allowanceBefore = allowance(allocatorAddress);
        _allocators.set(allocatorAddress, allowanceBefore + amount);
        emit AllowanceChanged(allocatorAddress, allowanceBefore, allowance(allocatorAddress));
    }

    function setAllowance(address allocatorAddress, uint256 amount) external onlyOwner {
        uint256 allowanceBefore = allowance(allocatorAddress);
        if (allowanceBefore == 0 && amount == 0) {
            revert CanNotSetAmoutEqualZeroForNonExistingUser();
        } else if (amount > 0) {
            _allocators.set(allocatorAddress, amount);
        } else if (allowanceBefore > 0 && amount == 0) {
            _allocators.remove(allocatorAddress);
        }
        emit AllowanceChanged(allocatorAddress, allowanceBefore, allowance(allocatorAddress));
    }

    /// @custom:oz-upgrades-unsafe-allow-reachable delegatecall
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

    function getAllocators() external view returns (address[] memory) {
        return _allocators.keys();
    }
}
