// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

interface IAllocator {
    error InsufficientAllowance();

    event AllowanceChanged(address indexed allocator, uint256 allowanceBefore, uint256 allowanceAfter);
    event DatacapAllocated(address indexed allocator, bytes indexed client, uint256 amount);

    /// List all accounts that have allowance
    function getAllocators() external view returns (address[] memory);

    /// Get allowance of an allocator
    function allowance(address allocator) external view returns (uint256);

    /// Add allowance
    /// @dev Emits AllowanceChanged event
    /// @dev Reverts if not called by contract owner
    function addAllowance(address allocator, uint256 amount) external;

    /// Set allowance (potentially removing it completely)
    /// @dev Emits AllowanceChanged event
    /// @dev Reverts if not called by contract owner
    function setAllowance(address allocator, uint256 amount) external;

    /// @dev Emits DatacapAllocated event
    /// @dev Reverts with InsufficientAllowance if caller doesn't have sufficient allowance
    function addVerifiedClient(bytes calldata clientAddress, uint256 amount) external;
}
