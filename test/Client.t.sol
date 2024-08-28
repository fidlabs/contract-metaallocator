// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {Client} from "../src/Client.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Errors} from "../src/libs/Errors.sol";
import {DataCapTypes} from "filecoin-project-filecoin-solidity/v0.8/types/DataCapTypes.sol";
import {CommonTypes} from "filecoin-project-filecoin-solidity/v0.8/types/CommonTypes.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IClient} from "../src/interfaces/IClient.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {BigInts} from "filecoin-project-filecoin-solidity/v0.8/utils/BigInts.sol";

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
    address public datacapContract = address(0xfF00000000000000000000000000000000000007);
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
            amount: CommonTypes.BigInt({val: hex"DE0B6B3A7640000000", neg: false}),
            //[[[1000, 42(h'000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA22'), 2048, 518400, 5256000, 305], [1000, 42(h'000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA22'), 2048, 518400, 5256000, 305]], []]
            operator_data: hex"8282861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A00503340190131861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180"
        });

        vm.startPrank(manager);
        clientContract.increaseAllowance(client, 4096);
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
        (uint256 tokenAmount,) = BigInts.toUint256(transferParams.amount);
        uint256 datacapAmount = tokenAmount / clientContract.TOKEN_PRECISION();
        vm.prank(client);
        vm.expectEmit(true, true, false, true);
        emit IClient.DatacapSpent(client, datacapAmount);
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
        clientContract.decreaseAllowance(client, 4096);
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(Errors.AlreadyZero.selector));
        clientContract.decreaseAllowance(client, 150);
    }

    function testDecreaseMoreAllowanceThanClientAlreadyHas() public {
        uint256 allowanceBefore = clientContract.allowances(client);
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit IClient.AllowanceChanged(client, allowanceBefore, 0);
        clientContract.decreaseAllowance(client, 5000);
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

        // client allowance is 4096
        // client has 2 SPs, so he can transfer max 2048 each

        vm.startPrank(client);

        // SP 1000
        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908011A0007E9001A0050334019013180";
        transferParams.amount.val = hex"6F139653EEC7640000"; // == 2049
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 2048, 2049));
        clientContract.transfer(transferParams);

        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";
        transferParams.amount.val = hex"6F05B59D3B20000000"; // == 2048
        clientContract.transfer(transferParams);

        // SP 1200
        transferParams.operator_data =
            hex"8281861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908011A0007E9001A0050334019013180";
        transferParams.amount.val = hex"6F139653EEC7640000"; // == 2049
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientAllowance.selector));
        clientContract.transfer(transferParams);

        transferParams.operator_data =
            hex"8281861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";
        transferParams.amount.val = hex"6F05B59D3B20000000"; // == 2048
        clientContract.transfer(transferParams);
    }

    function testZeroSlackWorksDoubleTransfer() public {
        allowedSPs_.push(1200);
        allowedSPs_.push(1000);
        vm.startPrank(manager);
        clientContract.setClientMaxDeviationFromFairDistribution(client, 0);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // client allowance is 4096
        // client has 2 SPs, so he can transfer max 2048 each

        vm.startPrank(client);

        // SP 1000
        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221907FE1A0007E9001A0050334019013180";
        transferParams.amount.val = hex"6EE9F42FD3D1380000"; // == 2046
        clientContract.transfer(transferParams);

        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA22041A0007E9001A0050334019013180";
        transferParams.amount.val = hex"3782DACE9D900000"; // == 4
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 2048, 2050));
        clientContract.transfer(transferParams);
    }

    function testZeroSlackWorksMixedAllocations() public {
        allowedSPs_.push(1200);
        allowedSPs_.push(1000);
        vm.startPrank(manager);
        clientContract.setClientMaxDeviationFromFairDistribution(client, 0);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // client allowance is 4096
        // client has 2 SPs, so he can transfer max 2048 each

        vm.startPrank(client);

        // SP 1000
        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA22183A1A0007E9001A0050334019013180";
        transferParams.amount.val = hex"0324E964B3ECA80000"; // == 58
        clientContract.transfer(transferParams);

        // half to 1000, half to 1200
        transferParams.operator_data =
            hex"8282861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221907E31A0007E9001A00503340190131861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221907E31A0007E9001A0050334019013180";
        transferParams.amount.val = hex"6F05B59D3B20000000"; // == 2048

        transferParams.amount.val = hex"DAE681D5C253580000"; // == 4038, all remaining allowance, so 1000 got 2019, but 1000 already got 58 earlier
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 2048, 2077));
        clientContract.transfer(transferParams);
    }

    function testZeroSlackWorksSingleAllocation() public {
        allowedSPs_.push(1200);
        allowedSPs_.push(1000);
        vm.startPrank(manager);
        clientContract.setClientMaxDeviationFromFairDistribution(client, 0);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // client allowance is 4096
        // client has 2 SPs, so he can transfer max 2048 each

        vm.startPrank(client);

        // single allocation, all to 1200
        transferParams.operator_data =
            hex"8281861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908011A0007E9001A0050334019013180";
        transferParams.amount.val = hex"6F139653EEC7640000"; // == 2049
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 2048, 2049));
        clientContract.transfer(transferParams);

        transferParams.operator_data =
            hex"8281861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908001A0007E9001A0050334019013180";
        transferParams.amount.val = hex"6F05B59D3B20000000"; // == 2048
        clientContract.transfer(transferParams);

        transferParams.operator_data =
            hex"8281861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA22011A0007E9001A0050334019013180";
        transferParams.amount.val = hex"0DE0B6B3A7640000"; // == 1
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 2048, 2049));
        clientContract.transfer(transferParams);
    }

    function test10SlackWorks() public {
        allowedSPs_.push(1200);
        allowedSPs_.push(1000);
        vm.startPrank(manager);
        clientContract.setClientMaxDeviationFromFairDistribution(client, clientContract.DENOMINATOR() / 10); // 10% slack, out of 4096 allowance, so 409
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // client allowance is 4096
        // client has 2 SPs, so he can transfer max 2048 + 409 slack each

        vm.startPrank(client);

        // SP 1000

        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221909C41A0007E9001A0050334019013180";
        transferParams.amount.val = hex"878678326EAC900000"; // == 2500
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 2457, 2500));
        clientContract.transfer(transferParams);

        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221909601A0007E9001A0050334019013180";
        transferParams.amount.val = hex"821AB0D44149800000"; // == 2400
        clientContract.transfer(transferParams);

        // SP 1200
        transferParams.operator_data =
            hex"8281861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221906A01A0007E9001A0050334019013180";
        transferParams.amount.val = hex"5BF0BA6634F6800000"; // == 1696
        clientContract.transfer(transferParams);
    }

    function test10SlackWorksDoubleTransfer() public {
        allowedSPs_.push(1200);
        allowedSPs_.push(1000);
        vm.startPrank(manager);
        clientContract.setClientMaxDeviationFromFairDistribution(client, clientContract.DENOMINATOR() / 10); // 10% slack, out of 4096 allowance, so 409
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // client allowance is 4096
        // client has 2 SPs, so he can transfer max 2048 + 409 slack each

        vm.startPrank(client);

        // SP 1000
        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221909601A0007E9001A0050334019013180";
        transferParams.amount.val = hex"821AB0D44149800000"; // == 2400
        clientContract.transfer(transferParams);

        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA22183A1A0007E9001A0050334019013180";
        transferParams.amount.val = hex"0324E964B3ECA80000"; // == 58
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 2457, 2458));
        clientContract.transfer(transferParams);
    }

    function test10SlackWorksMixedAllocations() public {
        allowedSPs_.push(1200);
        allowedSPs_.push(1000);
        vm.startPrank(manager);
        clientContract.setClientMaxDeviationFromFairDistribution(client, clientContract.DENOMINATOR() / 10); // 10% slack, out of 4096 allowance, so 409
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // client allowance is 4096
        // client has 2 SPs, so he can transfer max 2048 + 409 slack each

        vm.startPrank(client);

        // SP 1000
        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221903E81A0007E9001A0050334019013180";
        transferParams.amount.val = hex"3635C9ADC5DEA00000"; // == 1000
        clientContract.transfer(transferParams);

        // half to 1000, half to 1200
        transferParams.operator_data =
            hex"8282861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221905B21A0007E9001A00503340190131861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221905B21A0007E9001A0050334019013180";

        transferParams.amount.val = hex"9E13A1165EAF100000"; // == 2916, all remaining allowance, so 1000 got 1458, but 1000 already got 1000 earlier
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 2457, 2458));
        clientContract.transfer(transferParams);
    }

    function test10SlackWorksSingleAllocation() public {
        allowedSPs_.push(1200);
        allowedSPs_.push(1000);
        vm.startPrank(manager);
        clientContract.setClientMaxDeviationFromFairDistribution(client, clientContract.DENOMINATOR() / 10); // 10% slack, out of 4096 allowance, so 409
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        // client allowance is 4096
        // client has 2 SPs, so he can transfer max 2048 + 409 slack each

        vm.startPrank(client);

        // single allocation, all to 1200
        transferParams.operator_data =
            hex"8281861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA2219099A1A0007E9001A0050334019013180";
        transferParams.amount.val = hex"853F9A38F536280000"; // == 2458
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 2457, 2458));
        clientContract.transfer(transferParams);

        transferParams.operator_data =
            hex"8281861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221909991A0007E9001A0050334019013180";
        transferParams.amount.val = hex"8531B982418EC40000"; // == 2457
        clientContract.transfer(transferParams);

        transferParams.operator_data =
            hex"8281861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA22011A0007E9001A0050334019013180";
        transferParams.amount.val = hex"0DE0B6B3A7640000"; // == 1
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 2457, 2458));
        clientContract.transfer(transferParams);
    }

    function testTotalAllocationTracking() public {
        vm.startPrank(manager);
        allowedSPs_.push(1000);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);
        assertEq(clientContract.totalAllocations(client), 4096);

        clientContract.decreaseAllowance(client, 2048);
        assertEq(clientContract.totalAllocations(client), 2048);

        clientContract.increaseAllowance(client, 4096);
        assertEq(clientContract.totalAllocations(client), 6144);

        vm.startPrank(client);
        clientContract.transfer(transferParams);
        assertEq(clientContract.totalAllocations(client), 6144);

        vm.startPrank(manager);
        clientContract.decreaseAllowance(client, 2048);
        assertEq(clientContract.totalAllocations(client), 4096);
        assertEq(clientContract.allowances(client), 0);
    }

    function test10Slack3SPs() public {
        vm.startPrank(manager);
        allowedSPs_.push(1000);
        allowedSPs_.push(1200);
        allowedSPs_.push(1400);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);
        clientContract.increaseAllowance(client, 1904);
        clientContract.setClientMaxDeviationFromFairDistribution(client, clientContract.DENOMINATOR() / 50); // 2% slack, out of 6000 allowance, so 120

        // client allowance is 6000
        // client has 3 SPs, so he can transfer max 2000 + 120 slack each

        vm.startPrank(client);

        // single allocation, all to 1000
        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908491A0007E9001A0050334019013180";
        transferParams.amount.val = hex"7CAEE97613E6700000"; // == 2121
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 2120, 2121));
        clientContract.transfer(transferParams);
        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908341A0007E9001A0050334019013180";
        transferParams.amount.val = hex"71D75AB9B920500000"; // == 2120
        clientContract.transfer(transferParams);

        // single allocation, all to 1200
        transferParams.operator_data =
            hex"8281861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908491A0007E9001A0050334019013180";
        transferParams.amount.val = hex"7CAEE97613E6700000"; // == 2121
        vm.expectRevert(abi.encodeWithSelector(Errors.UnfairDistribution.selector, 2120, 2121));
        clientContract.transfer(transferParams);
        transferParams.operator_data =
            hex"8281861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908341A0007E9001A0050334019013180";
        transferParams.amount.val = hex"71D75AB9B920500000"; // == 2120
        clientContract.transfer(transferParams);

        // single allocation, all to 1400
        transferParams.operator_data =
            hex"828186190578D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221906E01A0007E9001A0050334019013180";
        transferParams.amount.val = hex"5F68E8131ECF800000"; // == 1760
        clientContract.transfer(transferParams);
    }

    function testClientAllocationsPerSpTrackedCorrectlySingleSPDoubleAlloc() public {
        vm.startPrank(manager);
        allowedSPs_.push(1000);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        vm.startPrank(client);

        // single allocation, all to 1000
        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221908FC1A0007E9001A0050334019013180";
        transferParams.amount.val = hex"7CAEE97613E6700000"; // == 2300
        clientContract.transfer(transferParams);

        (uint256[] memory providers, uint256[] memory allocations) = clientContract.clientAllocationsPerSP(client);
        assertEq(providers.length, 1);
        assertEq(providers[0], 1000);
        assertEq(allocations.length, 1);
        assertEq(allocations[0], 2300);

        transferParams.operator_data =
            hex"8281861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA22183A1A0007E9001A0050334019013180";
        transferParams.amount.val = hex"0324E964B3ECA80000"; // == 58
        clientContract.transfer(transferParams);

        (providers, allocations) = clientContract.clientAllocationsPerSP(client);
        assertEq(providers.length, 1);
        assertEq(providers[0], 1000);
        assertEq(allocations.length, 1);
        assertEq(allocations[0], 2358);
    }

    function testClientAllocationsPerSpTrackedCorrectlyTwosSPSingleTransfer() public {
        vm.startPrank(manager);
        allowedSPs_.push(1000);
        allowedSPs_.push(1200);
        clientContract.addAllowedSPsForClient(client, allowedSPs_);

        vm.startPrank(client);

        transferParams.operator_data =
            hex"8282861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221904001A0007E9001A00503340190131861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221904001A0007E9001A0050334019013180";
        transferParams.amount.val = hex"6F05B59D3B20000000"; // == 2048
        clientContract.transfer(transferParams);

        (uint256[] memory providers, uint256[] memory allocations) = clientContract.clientAllocationsPerSP(client);
        assertEq(providers.length, 2);
        assertEq(providers[0], 1200);
        assertEq(providers[1], 1000);
        assertEq(allocations.length, 2);
        assertEq(allocations[0], 1024);
        assertEq(allocations[1], 1024);

        transferParams.operator_data =
            hex"8282861904B0D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221902001A0007E9001A00503340190131861903E8D82A5828000181E203922020F2B9A58BBC9D9856E52EAB85155C1BA298F7E8DF458BD20A3AD767E11572CA221902001A0007E9001A0050334019013180";
        transferParams.amount.val = hex"3782DACE9D90000000"; // == 1024
        clientContract.transfer(transferParams);

        (providers, allocations) = clientContract.clientAllocationsPerSP(client);
        assertEq(providers.length, 2);
        assertEq(providers[0], 1200);
        assertEq(providers[1], 1000);
        assertEq(allocations.length, 2);
        assertEq(allocations[0], 1536);
        assertEq(allocations[1], 1536);
    }

    function testHandleFilecoinMethod() public {
        bytes memory params =
            hex"821A85223BDF58598607061903F34A006F05B59D3B2000000058458281861903E8D82A5828000181E2039220207DCAE81B2A679A3955CC2E4B3504C23CE55B2DB5DD2119841ECAFA550E53900E1908001A0007E9001A005033401A0002D3028040";
        vm.prank(datacapContract);
        (uint32 exitCode, uint64 codec, bytes memory data) =
            clientContract.handle_filecoin_method(3726118371, 0x51, params);
        assertEq(exitCode, 0);
        assertEq(codec, 0);
        assertEq(data, "");
    }

    function testHandleFilecoinMethodExpectRevertUnsupportedType() public {
        bytes memory params =
            hex"821A85223BDE585B861903F3061903F34A006F05B59D3B2000000058458281861903E8D82A5828000181E2039220207DCAE81B2A679A3955CC2E4B3504C23CE55B2DB5DD2119841ECAFA550E53900E1908001A0007E9001A005033401A0002D3028040";
        vm.prank(datacapContract);
        vm.expectRevert(abi.encodeWithSelector(Errors.UnsupportedType.selector));
        clientContract.handle_filecoin_method(3726118371, 81, params);
    }

    function testHandleFilecoinMethodExpectRevertInvalidTokenReceived() public {
        bytes memory params =
            hex"821A85223BDF585D871903F3061903F34A006F05B59D3B2000000058458281861903E8D82A5828000181E2039220207DCAE81B2A679A3955CC2E4B3504C23CE55B2DB5DD2119841ECAFA550E53900E1908001A0007E9001A005033401A0002D3028040187B";
        vm.prank(datacapContract);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTokenReceived.selector));
        clientContract.handle_filecoin_method(3726118371, 81, params);
    }

    function testHandleFilecoinMethodExpectRevertUnsupportedToken() public {
        bytes memory params =
            hex"821a85223bdf585b861903f3061903f34a006f05b59d3b2000000058458281861903e8d82a5828000181e2039220207dcae81b2a679a3955cc2e4b3504c23ce55b2db5dd2119841ecafa550e53900e1908001a0007e9001a005033401a0002d3028040";
        vm.prank(datacapContract);
        vm.expectRevert(abi.encodeWithSelector(Errors.UnsupportedToken.selector));
        clientContract.handle_filecoin_method(3726118371, 81, params);
    }

    function testHandleFilecoinMethodExpectRevertInvalidCaller() public {
        bytes memory params =
            hex"821a85223bdf585b861903f3061903f34a006f05b59d3b2000000058458281861903e8d82a5828000181e2039220207dcae81b2a679a3955cc2e4b3504c23ce55b2db5dd2119841ecafa550e53900e1908001a0007e9001a005033401a0002d3028040";
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidCaller.selector, address(this), datacapContract));
        clientContract.handle_filecoin_method(3726118371, 81, params);
    }
}
