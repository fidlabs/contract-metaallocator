// SPDX-License-Identifier: undefined
pragma solidity 0.8.25;

import {Allocator} from "../src/Allocator.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AllocatorHandler {
    Allocator public allocator;
    uint256 public sumOfNotaryAllowance;
    uint256 public sumOfGrantedAllowance;

    constructor() {
        address impl = address(new Allocator());
        ERC1967Proxy proxy = new ERC1967Proxy(impl, abi.encodeCall(Allocator.initialize, (address(this))));
        allocator = Allocator(address(proxy));
    }

    function addAllowanceAndTrack(address allocatorAddress, uint256 amount) external {
        allocator.addAllowance(allocatorAddress, amount);
        sumOfNotaryAllowance += amount;
    }

    function setAllowanceAndTrack(address allocatorAddress, uint256 amount) external {
        allocator.setAllowance(allocatorAddress, amount);
        sumOfNotaryAllowance = amount;
    }

    function addVerifiedClient(bytes calldata clientAddress, uint256 amount) external {
        allocator.addVerifiedClient(clientAddress, amount);
        sumOfGrantedAllowance += amount;
    }
}
