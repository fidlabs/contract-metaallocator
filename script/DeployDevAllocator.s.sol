// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {Allocator} from "../src/Allocator.sol";
import {Factory} from "../src/Factory.sol";

contract DeployDevAllocator is Script {
    Factory public factory;

    function run() external {
        vm.startBroadcast();
        address impl = address(new Allocator());
        factory = new Factory(address(this), impl);
        factory.deploy(address(this));
        vm.stopBroadcast();
    }
}
