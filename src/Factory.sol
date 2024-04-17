// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.25;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Allocator} from "./Allocator.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IFactory} from "./interfaces/IFactory.sol";

contract Factory is Ownable, IFactory {
    address[] public contracts;
    address public implementation;

    constructor(address initialOwner, address implementation_) Ownable(initialOwner) {
        implementation = implementation_;
    }

    function getContracts() external view returns (address[] memory) {
        return contracts;
    }

    function deploy(address owner) external {
        address proxy = address(new ERC1967Proxy(implementation, abi.encodeCall(Allocator.initialize, (owner))));
        emit Deployed(proxy);
        contracts.push(proxy);
    }

    function setImplementation(address implementation_) external onlyOwner {
        implementation = implementation_;
        emit NewImplementationSet(implementation_);
    }
}
