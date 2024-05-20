// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.25;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Allocator} from "./Allocator.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

/**
 * @title Allocator Factory
 * @notice Factory for deploying new instances of Allocator Contract. Factory
 * owner can update the implementation used for deploying new instances.
 */
contract Factory is Ownable, IFactory {
    /**
     * @notice List of contracts deployed by this Factory
     */
    address[] public contracts;

    /**
     * @notice Implementation used when deploying new contracts
     */
    address public implementation;

    /**
     * @notice Mapping from owner address to amount of deploys
     */
    mapping(address owner => uint256 deployCounter) public nonce;

    constructor(address initialOwner, address implementation_) Ownable(initialOwner) {
        implementation = implementation_;
    }

    /**
     * @notice Return all Allocator contracts deployed by this Factory
     * @return contracts_ Array of Allocator contract addresses
     */
    function getContracts() external view returns (address[] memory contracts_) {
        return contracts;
    }

    /**
     * @notice Deploy new allocator smart contract and register it in the registry
     * @param owner Initial Owner of the deployed contract
     * @dev Emits Deployed event
     */
    function deploy(address owner) external {
        bytes memory initCode = abi.encodePacked(
            type(ERC1967Proxy).creationCode, abi.encode(implementation, abi.encodeCall(Allocator.initialize, (owner)))
        );
        address proxy = Create2.deploy(0, keccak256(abi.encode(owner, nonce[owner])), initCode);
        emit Deployed(proxy);
        contracts.push(proxy);
        nonce[owner]++;
    }

    /**
     * @notice Set new implementation address used for deploying new contracts
     * @param implementation_ New implementation address
     * @dev Emits NewImplementationSet event
     * @dev Reverts if not called by contract owner
     */
    function setImplementation(address implementation_) external onlyOwner {
        implementation = implementation_;
        emit NewImplementationSet(implementation_);
    }
}
