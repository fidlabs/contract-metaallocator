// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Client} from "./Client.sol";
import {IBeaconProxyFactory} from "./interfaces/IBeaconProxyFactory.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

/**
 * @title BeaconProxy Factory
 * @notice Factory for deploying new instances of Client Contract. Factory
 * owner can update the implementation used for deploying new instances.
 */
contract BeaconProxyFactory is IBeaconProxyFactory {
    // slither-disable-next-line naming-convention
    UpgradeableBeacon public immutable BEACON;

    /**
     * @notice Mapping from manager address to amount of deploys
     */
    mapping(address manager => uint256 deployCounter) public nonce;

    constructor(address logic_) {
        BEACON = new UpgradeableBeacon(logic_, msg.sender);
    }

    /**
     * @notice Creates a new instance of an upgradeable contract.
     * @dev Uses BeaconProxy to create a new proxy instance, pointing to the Beacon for the logic contract.
     * @param manager_ The address of the manager responsible for the contract.
     */
    function create(address manager_) external {
        nonce[manager_]++;
        // slither-disable-next-line too-many-digits
        bytes memory initCode = abi.encodePacked(
            type(BeaconProxy).creationCode, abi.encode(address(BEACON), abi.encodeCall(Client.initialize, (manager_)))
        );
        address proxy = Create2.deploy(0, keccak256(abi.encode(manager_, nonce[manager_])), initCode);
        emit ProxyCreated(proxy);
    }
}
