// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.25;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IAllocator} from "./interfaces/IAllocator.sol";

contract Allocator is Initializable, OwnableUpgradeable, UUPSUpgradeable, IAllocator {
    mapping(address allocatorAddress => uint256 amount) public allowance;

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
        allowance[allocatorAddress] += amount;
        emit AllowanceChanged(allocatorAddress, allowanceBefore, allowance[allocatorAddress]);
    }

    function setAllowance(address allocatorAddress, uint256 amount) external onlyOwner {
        uint256 allowanceBefore = allowance[allocatorAddress];
        allowance[allocatorAddress] = amount;
        emit AllowanceChanged(allocatorAddress, allowanceBefore, allowance[allocatorAddress]);
    }

    // solhint-disable-next-line no-empty-blocks
    function addVerifiedClient(address clientAddress, uint256 amount) external onlyOwner {}

    // solhint-disable-next-line no-empty-blocks
    function allocators() external view returns (address[] memory) {}
}
