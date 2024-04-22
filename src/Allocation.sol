// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Errors} from "./libs/Errors.sol";

contract Allocation is Initializable {
    address public manager;
    address public client;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address manager_, address client_) public initializer {
        manager = manager_;
        client = client_;
    }

    //todo: implementation
    function transfer() external onlyClient {}

    //todo: implementation
    function setAllowedSPs(bytes[] calldata allowedSPs) external onlyManager {}
    /**
     * @notice This function sets the client address
     * @dev This function can only be called by the manager
     * @param client_ The address of the client
     */

    function setClient(address client_) external onlyManager {
        client = client_;
    }
    /**
     * @notice This function sets the manager address
     * @dev This function can only be called by the manager
     * @param manager_ The address of the manager
     */

    function setManager(address manager_) external onlyManager {
        manager = manager_;
    }

    /**
     * @dev modifier to check if the caller is the manager
     */
    modifier onlyManager() {
        if (msg.sender != manager) {
            revert Errors.NotManager();
        }
        _;
    }

    /**
     * @dev modifier to check if the caller is the client
     */
    modifier onlyClient() {
        if (msg.sender != client) {
            revert Errors.NotClient();
        }
        _;
    }
}
