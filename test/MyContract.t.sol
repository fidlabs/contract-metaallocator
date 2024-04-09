// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {MyContract} from "../src/MyContract.sol";
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

contract UUPSTest is Test {
    Deployer public deployer;
    Options public opts;
    MyContract public myContract;
    address public proxy; 

    function setUp() public {
        deployer = new Deployer();
        opts.referenceContract = "MyContract.sol";
        proxy = Upgrades.deployUUPSProxy("MyContract.sol", abi.encodeCall(MyContract.initialize, (address(this))));
    }

    function testUUPS() public {
        address implAddressV1 = Upgrades.getImplementationAddress(proxy);
        Upgrades.upgradeProxy(proxy, "MyContract.sol", "", opts, address(this));
        address implAddressV2 = Upgrades.getImplementationAddress(proxy);
        assertFalse(implAddressV2 == implAddressV1);
    }

    function testOwnable() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, vm.addr(2)));
        deployer.upgradeProxy(proxy, "MyContract.sol", "", opts, vm.addr(2));
    }

    function testAddAlowance() public {
        myContract = MyContract(proxy);
        uint256 currentAllowance = myContract.allowances(vm.addr(1));
        myContract.addAllowance(vm.addr(1), 100);
        uint256 newAllowance = myContract.allowances(vm.addr(1));
        assertTrue(currentAllowance + 100 == newAllowance);
    }

    function testOwnableAddAlowance() public {
        myContract = MyContract(proxy);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, vm.addr(1)));
        vm.prank(vm.addr(1));
        myContract.addAllowance(vm.addr(1), 100);
    }

    // function testSetAlowance() public {
    //     address proxy = Upgrades.deployUUPSProxy("MyContract.sol", abi.encodeCall(MyContract.initialize, (address(this))));
    //     myContract = MyContract(proxy);
    //     uint256 currentAllowance = myContract.allowances(vm.addr(1));
    //     myContract.addAllowance(vm.addr(1), 100);
    //     uint256 newAllowance = myContract.allowances(vm.addr(1));
    //     assertTrue(currentAllowance + 100 == newAllowance);
    // }

    // function testOwnableSetAlowance() public {
    //     address proxy = Upgrades.deployUUPSProxy("MyContract.sol", abi.encodeCall(MyContract.initialize, (vm.addr(1))));
    //     myContract = MyContract(proxy);
    //     vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, vm.addr(2)));
    //     vm.prank(vm.addr(1));
    //     myContract.addAllowance(vm.addr(1), 100);
    // }
}
