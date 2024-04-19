// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

interface IBeaconProxyFactory {
    /**
     * @notice Emitted when a new proxy is created.
     * @param proxy The address of the newly created proxy contract.
     */
    event ProxyCreated(address indexed proxy);

    /**
     * @notice Creates a new instance of an upgradeable contract.
     * @dev Uses BeaconProxy to create a new proxy instance, pointing to the Beacon for the logic contract.
     * @param manager_ The address of the manager responsible for the contract.
     */
    function create(address manager_) external;
}
