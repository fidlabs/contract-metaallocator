// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.25;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MyContract is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address allocatorAddress => uint256 amount) public allowances;

    event AllowanceChanged(address indexed allocatorAddress, uint256 newAllowance);

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
        allowances[allocatorAddress] += amount;
        emit AllowanceChanged(allocatorAddress, allowances[allocatorAddress]);
    }

    function setAllowance(address allocatorAddress, uint256 amount) external onlyOwner {
        allowances[allocatorAddress] == amount;
        emit AllowanceChanged(allocatorAddress, allowances[allocatorAddress]);
    }
}
