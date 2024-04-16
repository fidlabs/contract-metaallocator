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

contract Allocator is Initializable, OwnableUpgradeable, UUPSUpgradeable, IAllocator {
    mapping(address allocatorAddress => uint256 amount) public allowance;
    address[] public allocators;

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

    function addAllowance(address allocatorAddress, uint256 amount) external onlyOwner {
        uint256 allowanceBefore = allowance[allocatorAddress];
        if (allowanceBefore == 0) allocators.push(allocatorAddress);
        allowance[allocatorAddress] += amount;
        emit AllowanceChanged(allocatorAddress, allowanceBefore, allowance[allocatorAddress]);
    }

    function setAllowance(address allocatorAddress, uint256 amount) external onlyOwner {
        uint256 allowanceBefore = allowance[allocatorAddress];
        if (allowanceBefore == 0 && amount > 0) {
            allocators.push(allocatorAddress);
        } else if (allowanceBefore > 0 && amount == 0) {
            _removeFromAllocators(allocatorAddress);
        }
        allowance[allocatorAddress] = amount;
        emit AllowanceChanged(allocatorAddress, allowanceBefore, allowance[allocatorAddress]);
    }

    /// @custom:oz-upgrades-unsafe-allow-reachable delegatecall
    function addVerifiedClient(bytes calldata clientAddress, uint256 amount) external {
        uint256 allocatorBalance = allowance[msg.sender];
        if (allocatorBalance < amount) revert InsufficientAllowance();
        if (allocatorBalance - amount == 0) _removeFromAllocators(msg.sender);
        allowance[msg.sender] -= amount;
        emit DatacapAllocated(msg.sender, clientAddress, amount);
        VerifRegTypes.AddVerifiedClientParams memory params = VerifRegTypes.AddVerifiedClientParams({
            addr: FilAddresses.fromBytes(clientAddress),
            allowance: CommonTypes.BigInt(abi.encodePacked(amount), false)
        });
        VerifRegAPI.addVerifiedClient(params);
    }

    function getAllocators() external view returns (address[] memory) {
        return allocators;
    }

    function _removeFromAllocators(address addressToRemove) internal {
        for (uint256 i = 0; i < allocators.length; i++) {
            if (allocators[i] == addressToRemove) {
                allocators[i] = allocators[allocators.length - 1];
                allocators.pop();
            }
        }
    }
}
