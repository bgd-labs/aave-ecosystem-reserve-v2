// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {IInitializableAdminUpgradeabilityProxy} from "../interfaces/IInitializableAdminUpgradeabilityProxy.sol";
import {BaseTest} from "./base/BaseTest.sol";
import {AaveStreamingTreasuryV1} from "../AaveStreamingTreasuryV1.sol";
import {IAdminControlledTreasury} from "../interfaces/IAdminControlledTreasury.sol";
import {ISablier} from "../interfaces/ISablier.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {console} from "./utils/console.sol";

contract ValidationNewTreasury is BaseTest {
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

    IInitializableAdminUpgradeabilityProxy public constant COLLECTOR_V2_PROXY =
        IInitializableAdminUpgradeabilityProxy(
            0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c
        );

    address public constant GOV_SHORT_EXECUTOR =
        0xEE56e2B3D491590B5b31738cC34d5232F378a8D5;

    address public constant CONTROLLER_OF_COLLECTOR =
        0x7AB1e5c406F36FE20Ce7eBa528E182903CA8bFC7;

    address public constant RECIPIENT_STREAM_1 =
        0xd3B5A38aBd16e2636F1e94D1ddF0Ffb4161D5f10;

    address public constant AWETH = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e;

    function setUp() public {
        _initNewCollectorOnProxy();
    }

    function testCreation() public {
        _Creation_validate(
            AaveStreamingTreasuryV1(address(COLLECTOR_V2_PROXY))
        );
    }

    function testCancel() public {
        _Cancel_validate(AaveStreamingTreasuryV1(address(COLLECTOR_V2_PROXY)));
    }

    function _initNewCollectorOnProxy() internal returns (address) {
        AaveStreamingTreasuryV1 treasuryImpl = new AaveStreamingTreasuryV1();

        vm.deal(GOV_SHORT_EXECUTOR, 1 ether);
        vm.startPrank(GOV_SHORT_EXECUTOR);

        COLLECTOR_V2_PROXY.upgradeToAndCall(
            address(treasuryImpl),
            abi.encodeWithSelector(IAdminControlledTreasury.initialize.selector)
        );

        vm.stopPrank();

        return address(treasuryImpl);
    }

    function _Creation_validate(AaveStreamingTreasuryV1 treasuryProxy)
        internal
    {
        // Accounts not being funds admin can't create a stream
        vm.startPrank(address(1));
        vm.expectRevert(bytes("ONLY_BY_FUNDS_ADMIN"));
        treasuryProxy.createStream(
            RECIPIENT_STREAM_1,
            6 ether,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.stopPrank();

        // Recipients can'be be the 0x0, the collector or the controller of the collector
        vm.startPrank(CONTROLLER_OF_COLLECTOR);
        vm.expectRevert(bytes("stream to the zero address"));
        treasuryProxy.createStream(
            address(0),
            6 ether,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.expectRevert(bytes("stream to the contract itself"));
        treasuryProxy.createStream(
            address(treasuryProxy),
            6 ether,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.expectRevert(bytes("stream to the caller"));
        treasuryProxy.createStream(
            address(CONTROLLER_OF_COLLECTOR),
            6 ether,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );

        // Deposits need to be more than 0, more than duration in seconds and multiple of duration
        vm.expectRevert(bytes("deposit is zero"));
        treasuryProxy.createStream(
            RECIPIENT_STREAM_1,
            0,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.expectRevert(bytes("deposit smaller than time delta"));
        treasuryProxy.createStream(
            RECIPIENT_STREAM_1,
            59,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.expectRevert(bytes("deposit not multiple of time delta"));
        treasuryProxy.createStream(
            RECIPIENT_STREAM_1,
            61,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );

        // Start/stop times need to be consistent: start more than current current, stop later than start
        vm.expectRevert(bytes("start time before block.timestamp"));
        treasuryProxy.createStream(
            RECIPIENT_STREAM_1,
            6 ether,
            AWETH,
            block.timestamp - 10,
            (block.timestamp + 10) + 60
        );
        vm.expectRevert(bytes("stop time before the start time"));
        treasuryProxy.createStream(
            RECIPIENT_STREAM_1,
            6 ether,
            AWETH,
            block.timestamp + 10,
            block.timestamp
        );

        vm.expectEmit(true, true, true, true);
        emit CreateStream(
            100000,
            address(treasuryProxy),
            RECIPIENT_STREAM_1,
            6 ether,
            AWETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        uint256 streamId = treasuryProxy.createStream(
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
        ) = treasuryProxy.getStream(streamId);

        if (sender != address(treasuryProxy))
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
        if (treasuryProxy.nextStreamId() != (streamId + 1))
            revert Create_InvalidNextStreamId(treasuryProxy.nextStreamId());

        vm.stopPrank();
    }

    function _Cancel_validate(AaveStreamingTreasuryV1 treasuryProxy) internal {
        // Accounts not being funds admin can't create a stream
        vm.startPrank(address(1));
        vm.expectRevert(bytes("stream does not exist"));
        treasuryProxy.cancelStream(1);
        vm.stopPrank();

        vm.startPrank(CONTROLLER_OF_COLLECTOR);
        uint256 streamId = treasuryProxy.createStream(
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
        treasuryProxy.cancelStream(streamId);
        vm.stopPrank();

        // Admin can cancel the stream
        vm.startPrank(CONTROLLER_OF_COLLECTOR);

        uint256 balanceRecipientBefore = IERC20(AWETH).balanceOf(
            RECIPIENT_STREAM_1
        );

        vm.warp(block.timestamp + 20);
        vm.expectEmit(true, true, true, true);
        emit CancelStream(
            streamId,
            address(treasuryProxy),
            RECIPIENT_STREAM_1,
            (6 ether / 6) * 5,
            6 ether / 6
        );
        treasuryProxy.cancelStream(streamId);

        uint256 balanceRecipientAfter = IERC20(AWETH).balanceOf(
            RECIPIENT_STREAM_1
        );

        vm.expectRevert(bytes("stream does not exist"));
        treasuryProxy.getStream(streamId);

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

        vm.startPrank(CONTROLLER_OF_COLLECTOR);
        streamId = treasuryProxy.createStream(
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
            address(treasuryProxy),
            RECIPIENT_STREAM_1,
            6 ether,
            0
        );
        treasuryProxy.cancelStream(streamId);

        balanceRecipientAfter = IERC20(AWETH).balanceOf(RECIPIENT_STREAM_1);
        if (balanceRecipientBefore != balanceRecipientAfter)
            revert Cancel_WrongRecipientBalance(
                balanceRecipientAfter,
                balanceRecipientBefore
            );

        vm.stopPrank();
    }
}
