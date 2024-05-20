// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

/**
 * @title Interface for Allocator contract
 * @notice Definition of core functions and events of the Allocator contract
 */
interface IAllocator {
    /**
     * @dev Thrown if caller doesn't have enough allowance for given action
     */
    error InsufficientAllowance();

    /**
     * @dev Thrown if trying to add 0 allowance or grant 0 datacap
     */
    error AmountEqualZero();

    /**
     * @dev Thrown if trying to set allowance bigger than 0 when user has allowance, set allowance to 0 first if you want to set specific value
     */
    error AlreadyHasAllowance();

    /**
     * @dev Thrown if trying to set allowance to 0 when it's already 0
     */
    error AlreadyZero();

    /**
     * @notice Emitted when allocator's allowance is changed by manager
     * @param allocator Allocator whose allowance has changed
     * @param allowanceBefore Allowance before the change
     * @param allowanceAfter Allowance after the change
     */
    event AllowanceChanged(address indexed allocator, uint256 allowanceBefore, uint256 allowanceAfter);

    /**
     * @notice Emitted when datacap is granted to a client
     * @param allocator Allocator who granted the datacap
     * @param client Client that received datacap (Filecoin address)
     * @param amount Amount of datacap
     */
    event DatacapAllocated(address indexed allocator, bytes indexed client, uint256 amount);

    /**
     * @notice Get all allocators with non-zero allowance
     * @return allocators List of allocators with non-zero allowance
     */
    function getAllocators() external view returns (address[] memory allocators);

    /**
     * @notice Get allowance of an allocator
     * @param allocator Allocator to get allowance for
     * @return allowance Allocator's allowance
     */
    function allowance(address allocator) external view returns (uint256 allowance);

    /**
     * @notice Add allowance to Allocator
     * @param allocator Allocator that will receive allowance
     * @param amount Amount of allowance to add
     * @dev Emits AllowanceChanged event
     * @dev Reverts if not called by contract owner
     * @dev Reverts if trying to add 0 allowance
     */
    function addAllowance(address allocator, uint256 amount) external;

    /**
     * @notice Set allowance of an Allocator. Can be used to remove allowance.
     * @param allocator Allocator
     * @param amount Amount of allowance to set
     * @dev Emits AllowanceChanged event
     * @dev Reverts if not called by contract owner
     * @dev Reverts if setting to 0 when allocator already has 0 allowance
     */
    function setAllowance(address allocator, uint256 amount) external;

    /**
     * @notice Grant allowance to a client.
     * @param clientAddress Filecoin address of the client
     * @param amount Amount of datacap to grant
     * @dev Emits DatacapAllocated event
     * @dev Reverts with InsufficientAllowance if caller doesn't have sufficient allowance
     */
    function addVerifiedClient(bytes calldata clientAddress, uint256 amount) external;
}
