// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

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
    address public proxy;

    function setUp() public {
        deployer = new Deployer();
        opts.referenceContract = "Allocator.sol";
        proxy = Upgrades.deployUUPSProxy("Allocator.sol", abi.encodeCall(Allocator.initialize, (address(this))));
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
}
