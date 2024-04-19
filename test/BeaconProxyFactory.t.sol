// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {BeaconProxyFactory} from "../src/BeaconProxyFactory.sol";
import {Client} from "../src/Client.sol";
import {IBeaconProxyFactory} from "../src/interfaces/IBeaconProxyFactory.sol";

contract BeaconProxyFactoryTest is Test {
    BeaconProxyFactory public beaconProxyFactory;
    address public impl;

    function setUp() public {
        impl = address(new Client());
        beaconProxyFactory = new BeaconProxyFactory(impl);
    }

    function testDeployEmitEvent() public {
        vm.expectEmit(false, false, false, true);
        emit IBeaconProxyFactory.ProxyCreated(address(vm.addr(1)));
        beaconProxyFactory.create(address(vm.addr(2)));
    }

    function testDeployContract() public {
        address addr = address(new BeaconProxyFactory(impl));
        uint32 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(addr)
        }
        assertGt(size, 0);
    }
}
