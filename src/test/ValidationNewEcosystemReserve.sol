// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {IInitializableAdminUpgradeabilityProxy} from "../interfaces/IInitializableAdminUpgradeabilityProxy.sol";
import {BaseTest} from "./base/BaseTest.sol";
import {AaveEcosystemReserveV2} from "../AaveEcosystemReserveV2.sol";
import {AaveEcosystemReserveController} from "../AaveEcosystemReserveController.sol";
import {ApproximateMath} from "./utils/ApproximateMath.sol";
import {IAdminControlledEcosystemReserve} from "../interfaces/IAdminControlledEcosystemReserve.sol";
import {IStreamable} from "../interfaces/IStreamable.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {console} from "./utils/console.sol";

contract ValidationNewEcosystemReserve is BaseTest {
    event CreateStream(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        uint256 deposit,
        address tokenAddress,
        uint256 startTime,
        uint256 stopTime
    );

    event CancelStream(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        uint256 senderBalance,
        uint256 recipientBalance
    );

    event WithdrawFromStream(
        uint256 indexed streamId,
        address indexed recipient,
        uint256 amount
    );

    error Create_InvalidStreamId(uint256 id);
    error Create_InvalidSender(address sender);
    error Create_InvalidRecipient(address recipient);
    error Create_InvalidDeposit(uint256 amount);
    error Create_InvalidAsset(address asset);
    error Create_InvalidStartTime(uint256 startTime);
    error Create_InvalidStopTime(uint256 stopTime);
    error Create_InvalidRemaining(uint256 remainingBalance);
    error Create_InvalidRatePerSecond(uint256 rate);
    error Create_InvalidNextStreamId(uint256 id);
    error Cancel_WrongRecipientBalance(uint256 current, uint256 expected);
    error Withdraw_WrongRecipientBalance(uint256 current, uint256 expected);
    error Withdraw_WrongRecipientBalanceStream(
        uint256 current,
        uint256 expected
    );
    error Withdraw_WrongEcoReserveBalance(uint256 current, uint256 expected);
    error Withdraw_WrongEcoReserveBalanceStream(
        uint256 current,
        uint256 expected
    );

    IInitializableAdminUpgradeabilityProxy public constant COLLECTOR_V2_PROXY =
        IInitializableAdminUpgradeabilityProxy(
            0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c
        );

    address public constant GOV_SHORT_EXECUTOR =
        0xEE56e2B3D491590B5b31738cC34d5232F378a8D5;

    AaveEcosystemReserveController public controllerOfCollector;

    address public constant RECIPIENT_STREAM_1 =
        0xd3B5A38aBd16e2636F1e94D1ddF0Ffb4161D5f10;

    address public constant AWETH = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e;

    function setUp() public {
        _initNewCollectorOnProxy();
    }

    function test1Creation() public {
        _Creation_validate(
            AaveEcosystemReserveV2(payable(address(COLLECTOR_V2_PROXY)))
        );
    }

    function test2Cancel() public {
        _Cancel_validate(
            AaveEcosystemReserveV2(payable(address(COLLECTOR_V2_PROXY)))
        );
    }

    function test3Withdraw() public {
        _Withdraw_validate(
            AaveEcosystemReserveV2(payable(address(COLLECTOR_V2_PROXY)))
        );
    }

    function _initNewCollectorOnProxy() internal returns (address) {
        AaveEcosystemReserveV2 ecoReserveImpl = new AaveEcosystemReserveV2();

        controllerOfCollector = AaveEcosystemReserveController(
            0x3d569673dAa0575c936c7c67c4E6AedA69CC630C
        );

        vm.deal(GOV_SHORT_EXECUTOR, 1 ether);
        vm.startPrank(GOV_SHORT_EXECUTOR);

        COLLECTOR_V2_PROXY.upgradeToAndCall(
            address(ecoReserveImpl),
            abi.encodeWithSelector(
                IStreamable.initialize.selector,
                address(controllerOfCollector)
            )
        );

        vm.stopPrank();

        return address(ecoReserveImpl);
    }

    function _Creation_validate(AaveEcosystemReserveV2 ecoReserveProxy)
        internal
    {
        address fundsAdmin = address(controllerOfCollector);

        // Accounts not being funds admin can't create a stream
        vm.startPrank(address(1));
        vm.expectRevert(bytes("ONLY_BY_FUNDS_ADMIN"));
        ecoReserveProxy.createStream(
            RECIPIENT_STREAM_1,
            6 ether,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.stopPrank();

        // Recipients can'be be the 0x0, the collector or the controller of the collector
        vm.startPrank(fundsAdmin);
        vm.expectRevert(bytes("stream to the zero address"));
        ecoReserveProxy.createStream(
            address(0),
            6 ether,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.expectRevert(bytes("stream to the contract itself"));
        ecoReserveProxy.createStream(
            address(ecoReserveProxy),
            6 ether,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.expectRevert(bytes("stream to the caller"));
        ecoReserveProxy.createStream(
            address(fundsAdmin),
            6 ether,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );

        // Deposits need to be more than 0, more than duration in seconds and multiple of duration
        vm.expectRevert(bytes("deposit is zero"));
        ecoReserveProxy.createStream(
            RECIPIENT_STREAM_1,
            0,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.expectRevert(bytes("deposit smaller than time delta"));
        ecoReserveProxy.createStream(
            RECIPIENT_STREAM_1,
            59,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.expectRevert(bytes("deposit not multiple of time delta"));
        ecoReserveProxy.createStream(
            RECIPIENT_STREAM_1,
            61,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );

        // Start/stop times need to be consistent: start more than current current, stop later than start
        vm.expectRevert(bytes("start time before block.timestamp"));
        ecoReserveProxy.createStream(
            RECIPIENT_STREAM_1,
            6 ether,
            AWETH,
            block.timestamp - 10,
            (block.timestamp + 10) + 60
        );
        vm.expectRevert(bytes("stop time before the start time"));
        ecoReserveProxy.createStream(
            RECIPIENT_STREAM_1,
            6 ether,
            AWETH,
            block.timestamp + 10,
            block.timestamp
        );

        vm.expectEmit(true, true, true, true);
        emit CreateStream(
            100000,
            address(ecoReserveProxy),
            RECIPIENT_STREAM_1,
            6 ether,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        uint256 streamId = ecoReserveProxy.createStream(
            RECIPIENT_STREAM_1,
            6 ether,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        if (streamId != 100000) revert Create_InvalidStreamId(streamId);

        (
            address sender,
            address recipient,
            uint256 deposit,
            address tokenAddress,
            uint256 startTime,
            uint256 stopTime,
            uint256 remainingBalance,
            uint256 ratePerSecond
        ) = ecoReserveProxy.getStream(streamId);

        if (sender != address(ecoReserveProxy))
            revert Create_InvalidSender(sender);
        if (recipient != RECIPIENT_STREAM_1)
            revert Create_InvalidRecipient(recipient);
        if (deposit != 6 ether) revert Create_InvalidDeposit(deposit);
        if (tokenAddress != AWETH) revert Create_InvalidAsset(tokenAddress);
        if (startTime != (block.timestamp + 10))
            revert Create_InvalidStartTime(startTime);
        if (stopTime != ((block.timestamp + 10) + 60))
            revert Create_InvalidStopTime(stopTime);
        if (remainingBalance != 6 ether)
            revert Create_InvalidRemaining(remainingBalance);
        if (ratePerSecond != (6 ether / 60))
            revert Create_InvalidRatePerSecond(ratePerSecond);
        if (ecoReserveProxy.getNextStreamId() != (streamId + 1))
            revert Create_InvalidNextStreamId(
                ecoReserveProxy.getNextStreamId()
            );

        vm.stopPrank();
    }

    function _Cancel_validate(AaveEcosystemReserveV2 ecoReserveProxy) internal {
        address fundsAdmin = address(controllerOfCollector);

        // Accounts not being funds admin can't create a stream
        vm.startPrank(address(1));
        vm.expectRevert(bytes("stream does not exist"));
        ecoReserveProxy.cancelStream(1);
        vm.stopPrank();

        vm.startPrank(fundsAdmin);
        uint256 streamId = ecoReserveProxy.createStream(
            RECIPIENT_STREAM_1,
            6 ether,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.stopPrank();

        vm.startPrank(address(1));
        vm.expectRevert(
            bytes(
                "caller is not the funds admin or the recipient of the stream"
            )
        );
        ecoReserveProxy.cancelStream(streamId);
        vm.stopPrank();

        // Admin can cancel the stream
        vm.startPrank(fundsAdmin);

        uint256 balanceRecipientBefore = IERC20(AWETH).balanceOf(
            RECIPIENT_STREAM_1
        );

        vm.warp(block.timestamp + 20);
        vm.expectEmit(true, true, true, true);
        emit CancelStream(
            streamId,
            address(ecoReserveProxy),
            RECIPIENT_STREAM_1,
            (6 ether / 6) * 5,
            6 ether / 6
        );
        ecoReserveProxy.cancelStream(streamId);

        uint256 balanceRecipientAfter = IERC20(AWETH).balanceOf(
            RECIPIENT_STREAM_1
        );

        vm.expectRevert(bytes("stream does not exist"));
        ecoReserveProxy.getStream(streamId);

        if (balanceRecipientAfter != (balanceRecipientBefore + (6 ether / 6)))
            revert Cancel_WrongRecipientBalance(
                balanceRecipientAfter,
                balanceRecipientBefore + (6 ether / 6)
            );

        vm.stopPrank();

        // Transfer out of all aWETH, to avoid accounting for interest
        vm.startPrank(RECIPIENT_STREAM_1);
        IERC20(AWETH).transfer(
            address(1),
            IERC20(AWETH).balanceOf(RECIPIENT_STREAM_1)
        );
        vm.stopPrank();

        vm.startPrank(fundsAdmin);
        streamId = ecoReserveProxy.createStream(
            RECIPIENT_STREAM_1,
            6 ether,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.stopPrank();

        // Recipient can cancel the stream
        vm.startPrank(RECIPIENT_STREAM_1);
        balanceRecipientBefore = IERC20(AWETH).balanceOf(RECIPIENT_STREAM_1);
        vm.warp(block.timestamp + 10);
        vm.expectEmit(true, true, true, true);
        emit CancelStream(
            streamId,
            address(ecoReserveProxy),
            RECIPIENT_STREAM_1,
            6 ether,
            0
        );
        ecoReserveProxy.cancelStream(streamId);

        balanceRecipientAfter = IERC20(AWETH).balanceOf(RECIPIENT_STREAM_1);
        if (balanceRecipientBefore != balanceRecipientAfter)
            revert Cancel_WrongRecipientBalance(
                balanceRecipientAfter,
                balanceRecipientBefore
            );

        vm.stopPrank();
    }

    function _Withdraw_validate(AaveEcosystemReserveV2 ecoReserveProxy)
        internal
    {
        address fundsAdmin = address(controllerOfCollector);

        // Accounts not being funds admin can't create a stream
        vm.startPrank(address(1));
        vm.expectRevert(bytes("stream does not exist"));
        ecoReserveProxy.cancelStream(1);
        vm.stopPrank();

        vm.startPrank(fundsAdmin);
        uint256 streamId = ecoReserveProxy.createStream(
            RECIPIENT_STREAM_1,
            6 ether,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.stopPrank();

        vm.startPrank(address(1));
        vm.expectRevert(
            bytes(
                "caller is not the funds admin or the recipient of the stream"
            )
        );
        ecoReserveProxy.withdrawFromStream(streamId, 0);
        vm.stopPrank();

        vm.startPrank(fundsAdmin);
        vm.expectRevert(bytes("amount is zero"));
        ecoReserveProxy.withdrawFromStream(streamId, 0);

        vm.warp(block.timestamp + 20);
        vm.expectRevert(bytes("amount exceeds the available balance"));
        ecoReserveProxy.withdrawFromStream(streamId, 2 ether);

        uint256 balanceRecipientBefore = IERC20(AWETH).balanceOf(
            RECIPIENT_STREAM_1
        );
        uint256 balanceRecipientStreamBefore = ecoReserveProxy.balanceOf(
            streamId,
            RECIPIENT_STREAM_1
        );
        uint256 balanceEcoReserveBefore = IERC20(AWETH).balanceOf(
            address(ecoReserveProxy)
        );
        uint256 balanceEcoReserveStreamBefore = ecoReserveProxy.balanceOf(
            streamId,
            address(ecoReserveProxy)
        );

        vm.expectEmit(true, true, true, true);
        emit WithdrawFromStream(streamId, RECIPIENT_STREAM_1, 1 ether);
        ecoReserveProxy.withdrawFromStream(streamId, 1 ether);

        uint256 balanceRecipientAfter = IERC20(AWETH).balanceOf(
            RECIPIENT_STREAM_1
        );
        uint256 balanceRecipientStreamAfter = ecoReserveProxy.balanceOf(
            streamId,
            RECIPIENT_STREAM_1
        );
        uint256 balanceEcoReserveAfter = IERC20(AWETH).balanceOf(
            address(ecoReserveProxy)
        );
        uint256 balanceEcoReserveStreamAfter = ecoReserveProxy.balanceOf(
            streamId,
            address(ecoReserveProxy)
        );

        if (
            !(
                ApproximateMath._almostEqual(
                    balanceRecipientAfter,
                    balanceRecipientBefore + 1 ether
                )
            )
        ) {
            revert Withdraw_WrongRecipientBalance(
                balanceRecipientAfter,
                balanceRecipientBefore + 1 ether
            );
        }

        if (
            !(
                ApproximateMath._almostEqual(
                    balanceRecipientStreamAfter,
                    balanceRecipientStreamBefore - 1 ether
                )
            )
        ) {
            revert Withdraw_WrongRecipientBalanceStream(
                balanceRecipientStreamAfter,
                balanceRecipientStreamBefore - 1 ether
            );
        }

        if (
            !(
                ApproximateMath._almostEqual(
                    balanceEcoReserveAfter,
                    balanceEcoReserveBefore - 1 ether
                )
            )
        ) {
            revert Withdraw_WrongEcoReserveBalance(
                balanceEcoReserveAfter,
                balanceEcoReserveBefore - 1 ether
            );
        }

        if (
            !(
                ApproximateMath._almostEqual(
                    balanceEcoReserveStreamAfter,
                    balanceEcoReserveStreamBefore
                )
            )
        ) {
            revert Withdraw_WrongEcoReserveBalanceStream(
                balanceEcoReserveStreamAfter,
                balanceEcoReserveStreamBefore
            );
        }

        vm.warp(block.timestamp + 70);

        vm.stopPrank();

        // Transfer out of all aWETH, to avoid accounting for interest
        vm.startPrank(RECIPIENT_STREAM_1);
        IERC20(AWETH).transfer(
            address(1),
            IERC20(AWETH).balanceOf(RECIPIENT_STREAM_1)
        );

        balanceRecipientBefore = IERC20(AWETH).balanceOf(RECIPIENT_STREAM_1);
        balanceRecipientStreamBefore = ecoReserveProxy.balanceOf(
            streamId,
            RECIPIENT_STREAM_1
        );
        balanceEcoReserveBefore = IERC20(AWETH).balanceOf(
            address(ecoReserveProxy)
        );
        balanceEcoReserveStreamBefore = ecoReserveProxy.balanceOf(
            streamId,
            address(ecoReserveProxy)
        );

        vm.expectEmit(true, true, true, true);
        emit WithdrawFromStream(streamId, RECIPIENT_STREAM_1, 5 ether);
        ecoReserveProxy.withdrawFromStream(streamId, 5 ether);

        balanceRecipientAfter = IERC20(AWETH).balanceOf(RECIPIENT_STREAM_1);
        balanceEcoReserveAfter = IERC20(AWETH).balanceOf(
            address(ecoReserveProxy)
        );

        if (
            !(
                ApproximateMath._almostEqual(
                    balanceRecipientAfter,
                    balanceRecipientBefore + 5 ether
                )
            )
        ) {
            revert Withdraw_WrongRecipientBalance(
                balanceRecipientAfter,
                balanceRecipientBefore + 5 ether
            );
        }

        if (
            !(
                ApproximateMath._almostEqual(
                    balanceEcoReserveAfter,
                    balanceEcoReserveBefore - 5 ether
                )
            )
        ) {
            revert Withdraw_WrongEcoReserveBalance(
                balanceEcoReserveAfter,
                balanceEcoReserveBefore - 5 ether
            );
        }

        // We check the stream was deleted, just by calling a view function requiring existence
        vm.expectRevert("stream does not exist");
        balanceRecipientStreamAfter = ecoReserveProxy.balanceOf(
            streamId,
            RECIPIENT_STREAM_1
        );

        vm.stopPrank();
    }
}
