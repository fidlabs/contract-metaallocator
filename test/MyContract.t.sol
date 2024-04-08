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

    function setUp() public {
        deployer = new Deployer();
        opts.referenceContract = "MyContract.sol";
    }

    function testUUPS() public {
        address proxy = Upgrades.deployUUPSProxy("MyContract.sol", abi.encodeCall(MyContract.initialize, (vm.addr(1))));
        address implAddressV1 = Upgrades.getImplementationAddress(proxy);
        Upgrades.upgradeProxy(proxy, "MyContract.sol", "", opts, vm.addr(1));

        address implAddressV2 = Upgrades.getImplementationAddress(proxy);
        assertFalse(implAddressV2 == implAddressV1);
    }

    function testOwnable() public {
        address proxy = Upgrades.deployUUPSProxy("MyContract.sol", abi.encodeCall(MyContract.initialize, (vm.addr(1))));
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, vm.addr(2)));
        deployer.upgradeProxy(proxy, "MyContract.sol", "", opts, vm.addr(2));
    }
}
