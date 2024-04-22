// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {Allocation} from "../src/Allocation.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Errors} from "../src/libs/Errors.sol";

contract AllocationTest is Test {
    address public client = vm.addr(1);
    address public manager = vm.addr(2);
    address public unauthorized = vm.addr(3);
    address public client_ = vm.addr(4);
    address public manager_ = vm.addr(5);

    Allocation public allocation;

    function setUp() public {
        address beacon = Upgrades.deployBeacon("Allocation.sol", address(this));

        address proxy = Upgrades.deployBeaconProxy(beacon, abi.encodeCall(Allocation.initialize, (manager, client)));

        allocation = Allocation(proxy);
    }

    function testClientCanCallTransfer() public {
        vm.prank(client);
        allocation.transfer();

        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotClient.selector));
        allocation.transfer();
    }

    function testManagerCanSetAllowedSPs() public {
        vm.prank(manager);
        bytes[] memory allowedSPs = new bytes[](2);
        allowedSPs[0] = bytes("SP1");
        allowedSPs[1] = bytes("SP2");
        allocation.setAllowedSPs(allowedSPs);

        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotManager.selector));
        allocation.setAllowedSPs(allowedSPs);
    }

    function testManagerCanSetClient() public {
        vm.prank(manager);
        allocation.setClient(client_);
        assertEq(allocation.client(), client_);

        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotManager.selector));
        allocation.setClient(client_);
    }

    function testManagerCanSetManager() public {
        vm.prank(manager);
        allocation.setManager(manager_);
        assertEq(allocation.manager(), manager_);

        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotManager.selector));
        allocation.setManager(manager_);
    }
}
