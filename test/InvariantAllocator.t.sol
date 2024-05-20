// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {AllocatorHandler} from "./AllocatorHandler.sol";
import {VerifregActorMock} from "./Allocator.t.sol";

contract InvariantAllocatorTest is Test {
    AllocatorHandler public allocatorHandler;
    address public constant CALL_ACTOR_ID = 0xfe00000000000000000000000000000000000005;

    function setUp() external {
        allocatorHandler = new AllocatorHandler();
        VerifregActorMock verifregActorMock = new VerifregActorMock();
        vm.etch(CALL_ACTOR_ID, address(verifregActorMock).code);
        targetContract(address(allocatorHandler));
    }

    // solhint-disable-next-line func-name-mixedcase
    function invariant_A() external view {
        assertGe(allocatorHandler.sumOfNotaryAllowance(), allocatorHandler.sumOfGrantedAllowance());
    }
}
