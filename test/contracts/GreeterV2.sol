// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @custom:oz-upgrades-from test/contracts/Greeter.sol:Greeter
contract GreeterV2 is Initializable {
    string public greeting;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory greeting_) public {
        greeting = greeting_;
    }
    
    function hello() public view returns (string memory greeting_) {
        greeting_ = greeting;
    }
}
