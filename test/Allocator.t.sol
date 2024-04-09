// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {Allocator} from "../src/Allocator.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

contract Deployer {
    function upgradeProxy(
        address proxy,
        string calldata name,
        bytes calldata data,
        Options calldata opts,
        address caller
    ) external {
        Upgrades.upgradeProxy(proxy, name, data, opts, caller);
    }
}

contract AllocatorTest is Test {
    Deployer public deployer;
    Options public opts;
    Allocator public allocator;
    address public proxy;

    function setUp() public {
        deployer = new Deployer();
        opts.referenceContract = "Allocator.sol";
        proxy = Upgrades.deployUUPSProxy("Allocator.sol", abi.encodeCall(Allocator.initialize, (address(this))));
        allocator = Allocator(proxy);
    }

    function testUUPS() public {
        address implAddressV1 = Upgrades.getImplementationAddress(proxy);
        Upgrades.upgradeProxy(proxy, "Allocator.sol", "", opts, address(this));
        address implAddressV2 = Upgrades.getImplementationAddress(proxy);
        assertFalse(implAddressV2 == implAddressV1);
    }

    function testOwnable() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, vm.addr(1)));
        deployer.upgradeProxy(proxy, "Allocator.sol", "", opts, vm.addr(1));
    }

    function testAddAlowance() public {
        uint256 currentAllowance = allocator.allowance(vm.addr(1));
        allocator.addAllowance(vm.addr(1), 100);
        uint256 newAllowance = allocator.allowance(vm.addr(1));
        assertEq(currentAllowance + 100, newAllowance);
    }

    function testOwnableAddAlowance() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, vm.addr(1)));
        vm.prank(vm.addr(1));
        allocator.addAllowance(vm.addr(1), 100);
    }

    function testSetAlowance() public {
        uint256 currentAllowance = allocator.allowance(vm.addr(1));
        allocator.setAllowance(vm.addr(1), 100);
        uint256 allowanceAfterFirstSet = allocator.allowance(vm.addr(1));
        assertEq(currentAllowance + 100, allowanceAfterFirstSet);
        allocator.setAllowance(vm.addr(1), 10);
        uint256 allowanceAfterSecondSet = allocator.allowance(vm.addr(1));
        assertEq(allowanceAfterSecondSet, 10);
        allocator.setAllowance(vm.addr(1), 0);
        uint256 allowanceAfterSetToZero = allocator.allowance(vm.addr(1));
        assertEq(allowanceAfterSetToZero, 0);
    }

    function testOwnableSetAlowance() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, vm.addr(1)));
        vm.prank(vm.addr(1));
        allocator.setAllowance(vm.addr(1), 100);
    }
}
