// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {Allocator} from "../src/Allocator.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAllocator} from "../src/interfaces/IAllocator.sol";
import {Errors} from "../src/libs/Errors.sol";

contract VerifregActorMock {
    fallback(bytes calldata) external payable returns (bytes memory) {
        return abi.encode(0, 0x00, "");
    }
}

contract AllocatorTest is Test {
    Allocator public allocator;
    VerifregActorMock public verifregActorMock;
    address public constant CALL_ACTOR_ID = 0xfe00000000000000000000000000000000000005;

    function setUp() public {
        address impl = address(new Allocator());
        ERC1967Proxy proxy = new ERC1967Proxy(impl, abi.encodeCall(Allocator.initialize, (address(this))));
        allocator = Allocator(address(proxy));
        verifregActorMock = new VerifregActorMock();
        vm.etch(CALL_ACTOR_ID, address(verifregActorMock).code);
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
        allocator.setAllowance(vm.addr(1), 100);
        uint256 allowanceAfterFirstSet = allocator.allowance(vm.addr(1));
        assertEq(allowanceAfterFirstSet, 100);
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

    function testInsufficientAllowance() public {
        allocator.addAllowance(vm.addr(1), 100);
        vm.prank(vm.addr(1));
        //TODO use proper address
        vm.expectRevert(Errors.InsufficientAllowance.selector);
        allocator.addVerifiedClient("t1ur4z2o2k2rpyrhttkekijeep2vc34pwqwlt5nbi", 150);
    }

    function testDecreaseAllowanceAfterAddToClient() public {
        allocator.addAllowance(vm.addr(1), 100);
        vm.prank(vm.addr(1));
        allocator.addVerifiedClient("t1ur4z2o2k2rpyrhttkekijeep2vc34pwqwlt5nbi", 50);
        uint256 allowanceAfterAddToClient = allocator.allowance(vm.addr(1));
        assertEq(allowanceAfterAddToClient, 50);
        vm.prank(vm.addr(1));
        allocator.addVerifiedClient("t1ur4z2o2k2rpyrhttkekijeep2vc34pwqwlt5nbi", 50);
        uint256 allowanceAfterSecondAdd = allocator.allowance(vm.addr(1));
        assertEq(allowanceAfterSecondAdd, 0);
    }

    function testDatacapAllocatedEvent() public {
        allocator.addAllowance(vm.addr(1), 100);
        vm.prank(vm.addr(1));
        vm.expectEmit();
        emit IAllocator.DatacapAllocated(vm.addr(1), "t1ur4z2o2k2rpyrhttkekijeep2vc34pwqwlt5nbi", 50);
        allocator.addVerifiedClient("t1ur4z2o2k2rpyrhttkekijeep2vc34pwqwlt5nbi", 50);
    }

    function testVerifregActorExpectedCall() public {
        allocator.addAllowance(vm.addr(1), 100);
        vm.prank(vm.addr(1));
        vm.expectCall(CALL_ACTOR_ID, "");
        allocator.addVerifiedClient("t1ur4z2o2k2rpyrhttkekijeep2vc34pwqwlt5nbi", 50);
    }

    function testAddToAllocators() public {
        allocator.addAllowance(vm.addr(1), 100);
        address[] memory allocators = allocator.getAllocators();
        assertEq(allocators[0], vm.addr(1));
        assertEq(allocators.length, 1);
    }

    function testNoDuplicatesAllocators() public {
        allocator.addAllowance(vm.addr(1), 100);
        allocator.addAllowance(vm.addr(1), 200);
        address[] memory allocators = allocator.getAllocators();
        assertEq(allocators[0], vm.addr(1));
        assertEq(allocators.length, 1);
    }

    function testAllocatorsForMoreUsers() public {
        allocator.addAllowance(vm.addr(1), 100);
        allocator.addAllowance(vm.addr(2), 100);
        allocator.addAllowance(vm.addr(3), 100);
        address[] memory allocators = allocator.getAllocators();
        assertEq(allocators[0], vm.addr(1));
        assertEq(allocators[1], vm.addr(2));
        assertEq(allocators[2], vm.addr(3));
        assertEq(allocators.length, 3);
    }

    function testSetAllowance() public {
        allocator.setAllowance(vm.addr(1), 100);
        address[] memory allocators = allocator.getAllocators();
        assertEq(allocators[0], vm.addr(1));
        assertEq(allocators.length, 1);
    }

    function testDeleteFromAllocatorsAfterSetAllowanceToZeroForFirstUsers() public {
        allocator.setAllowance(vm.addr(1), 100);
        allocator.setAllowance(vm.addr(2), 100);
        allocator.setAllowance(vm.addr(3), 100);
        allocator.setAllowance(vm.addr(1), 0);
        address[] memory allocators = allocator.getAllocators();
        assertEq(allocators[0], vm.addr(3));
        assertEq(allocators[1], vm.addr(2));
        assertEq(allocators.length, 2);
    }

    function testDeleteFromAllocatorsAfterSetAllowanceToZeroForSecondUsers() public {
        allocator.setAllowance(vm.addr(1), 100);
        allocator.setAllowance(vm.addr(2), 100);
        allocator.setAllowance(vm.addr(3), 100);
        allocator.setAllowance(vm.addr(2), 0);
        address[] memory allocators = allocator.getAllocators();
        assertEq(allocators[0], vm.addr(1));
        assertEq(allocators[1], vm.addr(3));
        assertEq(allocators.length, 2);
    }

    function testDeleteFromAllocatorsAfterSetAllowanceToZeroForThirdUsers() public {
        allocator.setAllowance(vm.addr(1), 100);
        allocator.setAllowance(vm.addr(2), 100);
        allocator.setAllowance(vm.addr(3), 100);
        allocator.setAllowance(vm.addr(3), 0);
        address[] memory allocators = allocator.getAllocators();
        assertEq(allocators[0], vm.addr(1));
        assertEq(allocators[1], vm.addr(2));
        assertEq(allocators.length, 2);
    }

    function testRemoveFromAllocatorsAfterSetAlowanceToZero() public {
        allocator.setAllowance(vm.addr(1), 100);
        allocator.setAllowance(vm.addr(1), 0);
        address[] memory allocators = allocator.getAllocators();
        assertEq(allocators.length, 0);
    }

    function testRemoveFromAllocatorsAfterDrainsWholeAlowanceToZero() public {
        allocator.setAllowance(vm.addr(1), 100);
        vm.prank(vm.addr(1));
        allocator.addVerifiedClient("t1ur4z2o2k2rpyrhttkekijeep2vc34pwqwlt5nbi", 100);
        address[] memory allocators = allocator.getAllocators();
        assertEq(allocators.length, 0);
    }

    function testAddAllowanceWithAmountEqualZero() public {
        vm.expectRevert(Errors.AmountEqualZero.selector);
        allocator.addAllowance(vm.addr(1), 0);
    }

    function testAddVerifiedClientWithAmountEqualZero() public {
        vm.expectRevert(Errors.AmountEqualZero.selector);
        allocator.addVerifiedClient("t1ur4z2o2k2rpyrhttkekijeep2vc34pwqwlt5nbi", 0);
    }
}
