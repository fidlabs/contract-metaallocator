// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

interface IRegistry {
    struct Allowance {
        address allocatorContract;
        uint256 amount;
    }

    event Deployed(address deployedContractAddress);

    /// Return all allocator contracts known to the registry
    function contracts() external view returns (address[] memory);

    /// Return allowances of given allocator in all contracts known to the registry
    function allowedIn(address allocator) external view returns (Allowance[] memory);

    /// Deploy new allocator smart contract and register it in the registry
    /// @dev Emits Deployed event
    function deploy(address owner) external;
}
