// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Client} from "./Client.sol";
import {IBeaconProxyFactory} from "./interfaces/IBeaconProxyFactory.sol";

/**
 * @title BeaconProxy Factory
 * @notice Factory for deploying new instances of Allocation Contract. Factory
 * owner can update the implementation used for deploying new instances.
 */
contract BeaconProxyFactory is IBeaconProxyFactory {
    UpgradeableBeacon public immutable BEACON; // Calls the address of GreeterBeacon

    constructor(address logic_) {
        BEACON = new UpgradeableBeacon(logic_, msg.sender);
    }

    /**
     * @notice Creates a new instance of an upgradeable contract.
     * @dev Uses BeaconProxy to create a new proxy instance, pointing to the Beacon for the logic contract.
     * @param manager_ The address of the manager responsible for the contract.
     */
    function create(address manager_) external {
        BeaconProxy proxy =
            new BeaconProxy(address(BEACON), abi.encodeWithSelector(Client.initialize.selector, manager_));

        emit ProxyCreated(address(proxy));
    }
}
