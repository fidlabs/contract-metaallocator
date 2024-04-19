// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {Greeter} from "../src/Greeter.sol";
import {BeaconProxyFactory} from "../src/BeaconProxyFactory.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

contract UpgradesTest is Test {
    Options public opts;

    function setUp() public {
        opts.referenceContract = "Greeter.sol";
    }

    function testBeaconLib() public {
        address beacon = Upgrades.deployBeacon("Greeter.sol", address(this));
        address implAddressV1 = IBeacon(beacon).implementation();

        address proxy = Upgrades.deployBeaconProxy(beacon, abi.encodeCall(Greeter.initialize, ("hello")));
        Greeter instance = Greeter(proxy);

        assertEq(Upgrades.getBeaconAddress(proxy), beacon);

        assertEq(instance.greeting(), "hello");

        Upgrades.upgradeBeacon(beacon, "Greeter.sol", opts);
        address implAddressV2 = IBeacon(beacon).implementation();

        assertFalse(implAddressV2 == implAddressV1);
    }

    function testBeaconFactory() public {
        address implementationV1 = address(new Greeter());

        BeaconProxyFactory factory = new BeaconProxyFactory(address(implementationV1));

        address implAddressV1 = factory.BEACON().implementation();

        address implementationV2 = address(new Greeter());

        factory.BEACON().upgradeTo(implementationV2);

        address implAddressV2 = factory.BEACON().implementation();

        assertFalse(implAddressV2 == implAddressV1);
    }
}
