// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

interface IFactory {
    event Deployed(address deployedContractAddress);

    /// Return all allocator contracts known to the registry
    function contracts() external view returns (address[] memory);

    /// Deploy new allocator smart contract and register it in the registry
    /// @dev Emits Deployed event
    function deploy(address owner) external;
}
