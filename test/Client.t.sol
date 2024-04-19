// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {Client} from "../src/Client.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Errors} from "../src/libs/Errors.sol";
import {DataCapTypes} from "filecoin-solidity/contracts/v0.8/types/DataCapTypes.sol";
import {CommonTypes} from "filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IClient} from "../src/interfaces/IClient.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract VerifregActorMock {
    fallback(bytes calldata) external payable returns (bytes memory) {
        /// use CBOR_CODEC to return a cbor encoded response
        /// third parameter is the cbor encoded response
        return abi.encode(0, 0x51, hex"83410041004100");
    }
}

contract ClientTest is Test {
    address public client = vm.addr(1);
    address public manager = vm.addr(2);
    address public client_ = vm.addr(3);
    address public manager_ = vm.addr(4);
    uint64[] public allowedSPs_ = new uint64[](0);
    bytes public transferTo = abi.encodePacked(vm.addr(6));
    UpgradeableBeacon public beacon;

    DataCapTypes.TransferParams public transferParams;

    VerifregActorMock public verifregActorMock;
    address public constant CALL_ACTOR_ID = 0xfe00000000000000000000000000000000000005;

    Client public clientContract;

    modifier _startPrank(address addr) {
        vm.startPrank(addr);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        allowedSPs_.push(1000);

        address implementationV1 = address(new Client());

        beacon = new UpgradeableBeacon(implementationV1, address(this));

        BeaconProxy proxy =
            new BeaconProxy(address(beacon), abi.encodeWithSelector(Client(address(0)).initialize.selector, manager));

        clientContract = Client(address(proxy));

        verifregActorMock = new VerifregActorMock();
        vm.etch(CALL_ACTOR_ID, address(verifregActorMock).code);

        /// Dummy transfer params
        transferParams = DataCapTypes.TransferParams({
            to: CommonTypes.FilAddress(transferTo),
            amount: CommonTypes.BigInt({val: hex"64", neg: false}),
            //[[[1000, 42(h'000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA22'), 2048, 518400, 5256000, 305], [1000, 42(h'000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA22'), 2048, 518400, 5256000, 305]], []]
            operator_data: hex"8282861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A00503340190131861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180"
        });

        vm.prank(manager);
        clientContract.increaseAllowance(client, 100);
    }

    // function testInitialization() public view {
    //     assertEq(clientContract.manager(), manager);
    // }

    function testClientCanCallTransfer() public {
        allowedSPs_.push(1200);

        vm.prank(manager);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        vm.prank(client);
        clientContract.transfer(transferParams);
    }

    function testVerifregActorExpectTransferCall() public {
        vm.prank(manager);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        vm.prank(client);
        vm.expectCall(CALL_ACTOR_ID, "");
        clientContract.transfer(transferParams);
    }

    function testRemoveAllowedSPsForClient() public _startPrank(manager) {
        allowedSPs_.push(1200);

        clientContract.addAllowedSPsForClient(client, allowedSPs_);
        assertEq(clientContract.clientSPs(client, 1000), true);
        assertEq(clientContract.clientSPs(client, 1200), true);

        uint64[] memory spsToRemove = new uint64[](1);
        spsToRemove[0] = 1200;

        clientContract.removeAllowedSPsForClient(client, spsToRemove);

        assertEq(clientContract.clientSPs(client, 1200), false);
        assertEq(clientContract.clientSPs(client, 1000), true);
    }

    function testRemoveAllowedSPsForClientEvent() public _startPrank(manager) {
        allowedSPs_.push(1200);

        clientContract.addAllowedSPsForClient(client, allowedSPs_);
        uint64[] memory spsToRemove = new uint64[](1);
        spsToRemove[0] = 1200;
        vm.expectEmit(true, false, false, true);
        emit IClient.SPsRemovedForClient(client, spsToRemove);
        clientContract.removeAllowedSPsForClient(client, spsToRemove);
    }

    function testUnmatchedSPs() public {
        vm.prank(manager);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        //SP == 1200
        transferParams.operator_data =
            hex"8282861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A00503340190131861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";

        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotAllowedSP.selector));
        clientContract.transfer(transferParams);
    }

    function testInvalidAllocationRequest() public {
        vm.prank(manager);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // AllocationRequest length is 7 instead of 6
        transferParams.operator_data =
            hex"8282871904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A00503340190131190131861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";

        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAllocationRequest.selector));
        clientContract.transfer(transferParams);
    }

    function testInvalidOperatorDataLength() public {
        vm.prank(manager);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // operator_data == [[]]
        transferParams.operator_data = hex"8180";

        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidOperatorData.selector));
        clientContract.transfer(transferParams);
    }

    function testManagerCanAddAllowedSPs() public {
        uint64[] memory allowedSPs = new uint64[](2);
        allowedSPs[0] = 1;
        allowedSPs[1] = 2;
        vm.prank(manager);
        clientContract.addAllowedSPsForClient(client, allowedSPs);

        assertTrue(clientContract.clientSPs(client, allowedSPs[0]));
        assertTrue(clientContract.clientSPs(client, allowedSPs[1]));

        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, client));
        clientContract.addAllowedSPsForClient(client, allowedSPs);
    }

    function testNotManager() public {
        allowedSPs_.push(1200);
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, client));
        clientContract.addAllowedSPsForClient(client, allowedSPs_);
    }

    function testTransferEvent() public {
        vm.prank(manager);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);
        vm.prank(client);
        vm.expectEmit(true, true, false, true);
        emit IClient.DatacapAllocated(client, transferParams.to, transferParams.amount);
        clientContract.transfer(transferParams);
    }

    function testAddAllowedSPsEvent() public {
        vm.prank(manager);
        uint64[] memory allowedSPs = new uint64[](2);
        allowedSPs[0] = 1;
        allowedSPs[1] = 2;
        vm.expectEmit(true, false, false, true);
        emit IClient.SPsAddedForClient(client, allowedSPs);
        clientContract.addAllowedSPsForClient(client, allowedSPs);
    }

    function testIncreaseAllowanceRevertAmountError() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(Errors.AmountEqualZero.selector));
        clientContract.increaseAllowance(client, 0);
    }

    function testIncreaseAllowanceRevertNotManagerError() public {
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, client));
        clientContract.increaseAllowance(client, 100);
    }

    function testIncreaseAllowance() public {
        uint256 allowanceBefore = clientContract.allowances(client);
        vm.prank(manager);
        clientContract.increaseAllowance(client, 100);
        uint256 newAllowance = clientContract.allowances(client);
        assertEq(allowanceBefore + 100, newAllowance);
    }

    function testIncreaseAllowanceMoreTimes() public {
        uint256 allowanceBefore = clientContract.allowances(client);
        vm.prank(manager);
        clientContract.increaseAllowance(client, 25);
        uint256 newAllowance = clientContract.allowances(client);
        assertEq(allowanceBefore + 25, newAllowance);
        allowanceBefore = clientContract.allowances(client);
        vm.prank(manager);
        clientContract.increaseAllowance(client, 50);
        newAllowance = clientContract.allowances(client);
        assertEq(allowanceBefore + 50, newAllowance);
        allowanceBefore = clientContract.allowances(client);
        vm.prank(manager);
        clientContract.increaseAllowance(client, 100);
        newAllowance = clientContract.allowances(client);
        assertEq(allowanceBefore + 100, newAllowance);
    }

    function testIncreaseAllowanceEmitEvent() public {
        uint256 allowanceBefore = clientContract.allowances(client);
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IClient.AllowanceChanged(client, allowanceBefore, allowanceBefore + 100);
        clientContract.increaseAllowance(client, 100);
    }

    function testDecreaseAllowanceRevertAmountError() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(Errors.AmountEqualZero.selector));
        clientContract.decreaseAllowance(client, 0);
    }

    function testDecreaseAllowanceRevertNotManagerError() public {
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, client));
        clientContract.decreaseAllowance(client, 50);
    }

    function testDecreaseAllowanceAlreadyZeroError() public {
        vm.prank(manager);
        clientContract.decreaseAllowance(client, 100);
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(Errors.AlreadyZero.selector));
        clientContract.decreaseAllowance(client, 150);
    }

    function testDecreaseMoreAllowanceThanClientAlreadyHas() public {
        uint256 allowanceBefore = clientContract.allowances(client);
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IClient.AllowanceChanged(client, allowanceBefore, 0);
        clientContract.decreaseAllowance(client, 150);
        assertEq(clientContract.allowances(client), 0);
    }

    function testDecreaseAllowance() public {
        uint256 allowanceBefore = clientContract.allowances(client);
        vm.prank(manager);
        clientContract.decreaseAllowance(client, 50);
        uint256 newAllowance = clientContract.allowances(client);
        assertEq(allowanceBefore - 50, newAllowance);
    }

    function testDecreaseAllowanceMoreTimes() public {
        uint256 allowanceBefore = clientContract.allowances(client);
        vm.prank(manager);
        clientContract.decreaseAllowance(client, 25);
        uint256 newAllowance = clientContract.allowances(client);
        assertEq(allowanceBefore - 25, newAllowance);
        allowanceBefore = clientContract.allowances(client);
        vm.prank(manager);
        clientContract.decreaseAllowance(client, 50);
        newAllowance = clientContract.allowances(client);
        assertEq(allowanceBefore - 50, newAllowance);
        allowanceBefore = clientContract.allowances(client);
        vm.prank(manager);
        clientContract.decreaseAllowance(client, 25);
        newAllowance = clientContract.allowances(client);
        assertEq(allowanceBefore - 25, newAllowance);
    }

    function testDecreaseAllowanceEmitEvent() public {
        uint256 allowanceBefore = clientContract.allowances(client);
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IClient.AllowanceChanged(client, allowanceBefore, allowanceBefore - 50);
        clientContract.decreaseAllowance(client, 50);
    }

    function testTransferRevertInsufficientAllowance() public {
        vm.prank(manager);
        clientContract.decreaseAllowance(client, 50);

        allowedSPs_.push(1200);

        vm.prank(manager);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientAllowance.selector));
        clientContract.transfer(transferParams);
    }

    function testTransferRevertInvalidAmount() public {
        transferParams = DataCapTypes.TransferParams({
            to: CommonTypes.FilAddress(transferTo),
            amount: CommonTypes.BigInt({
                val: hex"010000000000000000000000000000000000000000000000000000000000000000",
                neg: false
            }),
            operator_data: hex"8282861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A00503340190131861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180"
        });

        allowedSPs_.push(1200);

        vm.prank(manager);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAmount.selector));
        clientContract.transfer(transferParams);
    }

    function testRevertRenounceOwnership() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(Errors.FunctionDisabled.selector));
        clientContract.renounceOwnership();
    }

    function testOwnershipRenounceOwnership() public {
        vm.prank(client);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, client));
        clientContract.renounceOwnership();
    }
}
