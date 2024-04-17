// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

interface IFactory {
    event Deployed(address deployedContractAddress);
    event NewImplementationSet(address implemetation_);

    /// Return all allocator contracts known to the registry
    function getContracts() external view returns (address[] memory);

    /// Deploy new allocator smart contract and register it in the registry
    /// @dev Emits Deployed event
    function deploy(address owner) external;

    /// Set new implementation address
    /// @dev Emits NewImplementationSet event
    /// @dev Reverts if not called by contract owner
    function setImplementation(address implementation_) external;
}
