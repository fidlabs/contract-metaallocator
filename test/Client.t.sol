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

// solhint-disable reentrancy
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

    function _contains(uint256 needle, uint256[] memory haystack) internal pure returns (bool) {
        for (uint256 i = 0; i < haystack.length; i++) {
            if (haystack[i] == needle) {
                return true;
            }
        }
        return false;
    }

    function setUp() public {
        allowedSPs_.push(1000);

        address implementationV1 = address(new Client());

        beacon = new UpgradeableBeacon(implementationV1, address(this));

        BeaconProxy proxy =
            new BeaconProxy(address(beacon), abi.encodeWithSelector(Client.initialize.selector, manager));

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

        vm.startPrank(manager);
        clientContract.increaseAllowance(client, 100);
        clientContract.setClientMaxDeviationFromFairDistribution(client, clientContract.DENOMINATOR());
        vm.stopPrank();
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
        assertTrue(_contains(1000, clientContract.clientSPs(client)));
        assertTrue(_contains(1200, clientContract.clientSPs(client)));

        uint64[] memory spsToRemove = new uint64[](1);
        spsToRemove[0] = 1200;

        clientContract.removeAllowedSPsForClient(client, spsToRemove);

        assertFalse(_contains(1200, clientContract.clientSPs(client)));
        assertTrue(_contains(1000, clientContract.clientSPs(client)));
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

        assertTrue(_contains(allowedSPs[0], clientContract.clientSPs(client)));
        assertTrue(_contains(allowedSPs[1], clientContract.clientSPs(client)));

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

    function testZeroSlackWorks() public {
        allowedSPs_.push(1200);
        allowedSPs_.push(1000);
        vm.startPrank(manager);
        clientContract.setClientMaxDeviationFromFairDistribution(client, 0);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // client allowance is 100
        // client has 2 SPs, so he can transfer max 50 each

        vm.startPrank(client);

        // SP 1000
        transferParams.amount.val = hex"34"; // == 52
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 50, 52));
        clientContract.transfer(transferParams);
        transferParams.amount.val = hex"30"; // == 48
        clientContract.transfer(transferParams);

        // SP 1200
        transferParams.operator_data =
            hex"8282861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A00503340190131861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";
        transferParams.amount.val = hex"34"; // == 52
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 50, 52));
        clientContract.transfer(transferParams);
        transferParams.amount.val = hex"32"; // == 50
        clientContract.transfer(transferParams);
    }

    function testZeroSlackWorksDoubleTransfer() public {
        allowedSPs_.push(1200);
        allowedSPs_.push(1000);
        vm.startPrank(manager);
        clientContract.setClientMaxDeviationFromFairDistribution(client, 0);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // client allowance is 100
        // client has 2 SPs, so he can transfer max 50 each

        vm.startPrank(client);

        // SP 1000
        transferParams.amount.val = hex"30"; // == 48
        clientContract.transfer(transferParams);

        transferParams.amount.val = hex"04"; // == 4
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 50, 52));
        clientContract.transfer(transferParams);
    }

    function testZeroSlackWorksMixedAllocations() public {
        allowedSPs_.push(1200);
        allowedSPs_.push(1000);
        vm.startPrank(manager);
        clientContract.setClientMaxDeviationFromFairDistribution(client, 0);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // client allowance is 100
        // client has 2 SPs, so he can transfer max 50 each

        vm.startPrank(client);

        // SP 1000
        transferParams.amount.val = hex"02"; // == 2
        clientContract.transfer(transferParams);

        // half to 1000, half to 1200
        transferParams.operator_data =
            hex"8282861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A00503340190131861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";

        transferParams.amount.val = hex"62"; // == 98, all remaining allowance, so 1000 will get 49, but already got 2 earlier
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 50, 51));
        clientContract.transfer(transferParams);
    }

    function testZeroSlackWorksSingleAllocation() public {
        allowedSPs_.push(1200);
        allowedSPs_.push(1000);
        vm.startPrank(manager);
        clientContract.setClientMaxDeviationFromFairDistribution(client, 0);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // client allowance is 100
        // client has 2 SPs, so he can transfer max 50 each

        vm.startPrank(client);

        // single allocation, all to 1200
        transferParams.operator_data =
            hex"8281861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";
        transferParams.amount.val = hex"33"; // == 51
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 50, 51));
        clientContract.transfer(transferParams);

        transferParams.amount.val = hex"32"; // == 50
        clientContract.transfer(transferParams);

        transferParams.amount.val = hex"01"; // == 1
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 50, 51));
        clientContract.transfer(transferParams);
    }

    function test10SlackWorks() public {
        allowedSPs_.push(1200);
        allowedSPs_.push(1000);
        vm.startPrank(manager);
        clientContract.setClientMaxDeviationFromFairDistribution(client, clientContract.DENOMINATOR() / 10); // 10% slack, out of 100 allowance, so 10
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // client allowance is 100
        // client has 2 SPs, so he can transfer max 50 + 10 slack each

        vm.startPrank(client);

        // SP 1000
        transferParams.amount.val = hex"3E"; // == 62
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 60, 62));
        clientContract.transfer(transferParams);
        transferParams.amount.val = hex"3A"; // == 58
        clientContract.transfer(transferParams);

        // SP 1200
        transferParams.operator_data =
            hex"8282861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A00503340190131861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";
        transferParams.amount.val = hex"2A"; // == 42
        clientContract.transfer(transferParams);
    }

    function test10SlackWorksDoubleTransfer() public {
        allowedSPs_.push(1200);
        allowedSPs_.push(1000);
        vm.startPrank(manager);
        clientContract.setClientMaxDeviationFromFairDistribution(client, clientContract.DENOMINATOR() / 10); // 10% slack, out of 100 allowance, so 10
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // client allowance is 100
        // client has 2 SPs, so he can transfer max 50 + 10 slack each

        vm.startPrank(client);

        // SP 1000
        transferParams.amount.val = hex"3A"; // == 58
        clientContract.transfer(transferParams);

        transferParams.amount.val = hex"04"; // == 4
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 60, 62));
        clientContract.transfer(transferParams);
    }

    function test10SlackWorksMixedAllocations() public {
        allowedSPs_.push(1200);
        allowedSPs_.push(1000);
        vm.startPrank(manager);
        clientContract.setClientMaxDeviationFromFairDistribution(client, clientContract.DENOMINATOR() / 10); // 10% slack, out of 100 allowance, so 10
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // client allowance is 100
        // client has 2 SPs, so he can transfer max 50 + 10 slack each

        vm.startPrank(client);

        // SP 1000
        transferParams.amount.val = hex"16"; // == 22
        clientContract.transfer(transferParams);

        // half to 1000, half to 1200
        transferParams.operator_data =
            hex"8282861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A00503340190131861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";

        transferParams.amount.val = hex"4E"; // == 78, all remaining allowance, so 1000 will get 39, but already got 22 earlier
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 60, 61));
        clientContract.transfer(transferParams);
    }

    function test10SlackWorksSingleAllocation() public {
        allowedSPs_.push(1200);
        allowedSPs_.push(1000);
        vm.startPrank(manager);
        clientContract.setClientMaxDeviationFromFairDistribution(client, clientContract.DENOMINATOR() / 10); // 10% slack, out of 100 allowance, so 10
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // client allowance is 100
        // client has 2 SPs, so he can transfer max 50 + 10 slack each

        vm.startPrank(client);

        // single allocation, all to 1200
        transferParams.operator_data =
            hex"8281861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";
        transferParams.amount.val = hex"3D"; // == 61
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 60, 61));
        clientContract.transfer(transferParams);

        transferParams.amount.val = hex"3C"; // == 60
        clientContract.transfer(transferParams);

        transferParams.amount.val = hex"01"; // == 1
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 60, 61));
        clientContract.transfer(transferParams);
    }

    function testTotalAllocationTracking() public {
        vm.startPrank(manager);
        allowedSPs_.push(1000);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);
        assertEq(clientContract.totalAllocations(client), 100);

        clientContract.decreaseAllowance(client, 50);
        assertEq(clientContract.totalAllocations(client), 50);

        clientContract.increaseAllowance(client, 100);
        assertEq(clientContract.totalAllocations(client), 150);

        vm.startPrank(client);
        clientContract.transfer(transferParams);
        assertEq(clientContract.totalAllocations(client), 150);

        vm.startPrank(manager);
        clientContract.decreaseAllowance(client, 50);
        assertEq(clientContract.totalAllocations(client), 100);
        assertEq(clientContract.allowances(client), 0);
    }

    function test10Slack3SPs() public {
        vm.startPrank(manager);
        allowedSPs_.push(1000);
        allowedSPs_.push(1200);
        allowedSPs_.push(1400);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);
        clientContract.increaseAllowance(client, 50);
        clientContract.setClientMaxDeviationFromFairDistribution(client, clientContract.DENOMINATOR() / 50); // 2% slack, out of 150 allowance, so 3

        // client allowance is 150
        // client has 2 SPs, so he can transfer max 50 + 10 slack each

        vm.startPrank(client);

        // single allocation, all to 1000
        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";
        transferParams.amount.val = hex"36"; // == 54
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 53, 54));
        clientContract.transfer(transferParams);
        transferParams.amount.val = hex"35"; // == 53
        clientContract.transfer(transferParams);

        // single allocation, all to 1200
        transferParams.operator_data =
            hex"8281861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";
        transferParams.amount.val = hex"36"; // == 54
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 53, 54));
        clientContract.transfer(transferParams);
        transferParams.amount.val = hex"35"; // == 53
        clientContract.transfer(transferParams);

        // single allocation, all to 1400
        transferParams.operator_data =
            hex"828186190578D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";
        transferParams.amount.val = hex"2C"; // == 44
        clientContract.transfer(transferParams);
    }

    function testClientAllocationsPerSpTrackedCorrectly() public {
        vm.startPrank(manager);
        allowedSPs_.push(1000);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        vm.startPrank(client);

        // single allocation, all to 1000
        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";
        transferParams.amount.val = hex"35"; // == 53
        clientContract.transfer(transferParams);

        (uint256[] memory providers, uint256[] memory allocations) = clientContract.clientAllocationsPerSP(client);
        assertEq(providers.length, 1);
        assertEq(providers[0], 1000);
        assertEq(allocations.length, 1);
        assertEq(allocations[0], 53);

        transferParams.amount.val = hex"0a"; // == 10
        clientContract.transfer(transferParams);

        (providers, allocations) = clientContract.clientAllocationsPerSP(client);
        assertEq(providers.length, 1);
        assertEq(providers[0], 1000);
        assertEq(allocations.length, 1);
        assertEq(allocations[0], 63);
    }

    function testClientAllocationsPerSpTrackedCorrectlySingleSPDoubleAlloc() public {
        vm.startPrank(manager);
        allowedSPs_.push(1000);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        vm.startPrank(client);

        transferParams.amount.val = hex"34"; // == 52
        clientContract.transfer(transferParams);

        (uint256[] memory providers, uint256[] memory allocations) = clientContract.clientAllocationsPerSP(client);
        assertEq(providers.length, 1);
        assertEq(providers[0], 1000);
        assertEq(allocations.length, 1);
        assertEq(allocations[0], 52);

        transferParams.amount.val = hex"0a"; // == 10
        clientContract.transfer(transferParams);

        (providers, allocations) = clientContract.clientAllocationsPerSP(client);
        assertEq(providers.length, 1);
        assertEq(providers[0], 1000);
        assertEq(allocations.length, 1);
        assertEq(allocations[0], 62);
    }

    function testClientAllocationsPerSpTrackedCorrectlyTwosSPSingleTransfer() public {
        vm.startPrank(manager);
        allowedSPs_.push(1000);
        allowedSPs_.push(1200);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        vm.startPrank(client);

        transferParams.operator_data =
            hex"8282861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A00503340190131861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";
        transferParams.amount.val = hex"32"; // == 50
        clientContract.transfer(transferParams);

        (uint256[] memory providers, uint256[] memory allocations) = clientContract.clientAllocationsPerSP(client);
        assertEq(providers.length, 2);
        assertEq(providers[0], 1200);
        assertEq(providers[1], 1000);
        assertEq(allocations.length, 2);
        assertEq(allocations[0], 25);
        assertEq(allocations[1], 25);

        transferParams.amount.val = hex"0a"; // == 10
        clientContract.transfer(transferParams);

        (providers, allocations) = clientContract.clientAllocationsPerSP(client);
        assertEq(providers.length, 2);
        assertEq(providers[0], 1200);
        assertEq(providers[1], 1000);
        assertEq(allocations.length, 2);
        assertEq(allocations[0], 30);
        assertEq(allocations[1], 30);
    }
}
