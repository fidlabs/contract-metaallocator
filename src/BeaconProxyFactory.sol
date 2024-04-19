// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Greeter} from "./Greeter.sol";
//Creates instances of upgradeable contracts using the Beacon Proxy Pattern.
//Relies on the contract GreeterBeacon for managing the logic contract addresses

contract BeaconProxyFactory {
    event ProxyCreated(address proxy);

    UpgradeableBeacon public immutable BEACON; // Calls the address of GreeterBeacon

    constructor(address logic_) {
        BEACON = new UpgradeableBeacon(logic_, msg.sender);
    }

    //Creates a new instance of an upgradeable contract.Uses BeaconProxy to create a new BeaconProxy.
    //Passes the address of the Beacon and it calls the initialiazation parameter for GreeterV1

    function create(string calldata greeting_) external {
        BeaconProxy proxy =
            new BeaconProxy(address(BEACON), abi.encodeWithSelector(Greeter(address(0)).initialize.selector, greeting_));

        emit ProxyCreated(address(proxy));
    }
}
