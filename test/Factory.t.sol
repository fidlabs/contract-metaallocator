// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {Allocator} from "../src/Factory.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FactoryTest is Test {
    Factory public factory;
    address public impl;

    function setUp() public {
        impl = address(new Allocator());
        factory = new Factory(address(this), impl);
    }

    function testRevertSetImplementation() public {
        address newImpl = address(new Allocator());
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, vm.addr(1)));
        vm.prank(vm.addr(1));
        factory.setImplementation(newImpl);
    }

    function testSetImplementationEmitEvent() public {
        address newImpl = address(new Allocator());
        vm.expectEmit(false, false, false, true);
        emit IFactory.NewImplementationSet(newImpl);
        factory.setImplementation(newImpl);
    }

    function testImplementationAfterSetImplementation() public {
        address newImpl = address(new Allocator());
        factory.setImplementation(newImpl);
        assertEq(newImpl, factory.implementation());
    }

    function testUpdateContracts() public {
        factory.deploy(address(this));
        address[] memory contracts = factory.getContracts();
        assertEq(contracts.length, 1);
        factory.deploy(address(this));
        address[] memory contractsAfterSecondDeploy = factory.getContracts();
        assertEq(contractsAfterSecondDeploy.length, 2);
    }

    function testDeployEmitEvent() public {
        vm.expectEmit(false, false, false, false);
        emit IFactory.Deployed(address(vm.addr(1)));
        factory.deploy(address(this));
    }

    function testDeployContract() public {
        address addr = address(new Factory(address(this), impl));
        uint32 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(addr)
        }
        assertGt(size, 0);
    }

    function testRevertRenounceOwnership() public {
        vm.expectRevert(IFactory.FunctionDisabled.selector);
        factory.renounceOwnership();
    }

    function testOwnershipRenounceOwnership() public {
        vm.prank(vm.addr(1));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, vm.addr(1)));
        factory.renounceOwnership();
    }

    function testDifferentAddressesPerOwner() public {
        factory.deploy(address(this));
        factory.deploy(vm.addr(1));
        address[] memory contracts = factory.getContracts();
        assertNotEq(contracts[0], contracts[1]);
    }

    function testNewAddressPerContract() public {
        factory.deploy(address(this));
        factory.deploy(address(this));
        address[] memory contracts = factory.getContracts();
        assertNotEq(contracts[0], contracts[1]);
    }
}
