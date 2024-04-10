// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {Allocator} from "../src/Allocator.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

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
}
