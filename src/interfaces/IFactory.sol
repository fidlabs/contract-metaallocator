// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

interface IFactory {
    /**
     * @notice Emitted when new Allocator contract is deployed
     * @param deployedContractAddress Address of the deployed contract
     */
    event Deployed(address deployedContractAddress);

    /**
     * @notice Emitted when implementation for new contracts is changed
     * @param implementation Address of the new implementation
     */
    event NewImplementationSet(address implementation);

    /**
     * @notice Return all Allocator contracts deployed by this Factory
     * @return contracts Array of Allocator contract addresses
     */
    function getContracts() external view returns (address[] memory contracts);

    /**
     * @notice Deploy new allocator smart contract and register it in the registry
     * @param owner Initial Owner of the deployed contract
     * @dev Emits Deployed event
     */
    function deploy(address owner) external;

    /**
     * @notice Set new implementation address used for deploying new contracts
     * @param implementation_ New implementation address
     * @dev Emits NewImplementationSet event
     * @dev Reverts if not called by contract owner
     */
    function setImplementation(address implementation_) external;
}
