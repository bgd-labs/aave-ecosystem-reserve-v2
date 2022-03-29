// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {IInitializableAdminUpgradeabilityProxy} from "../interfaces/IInitializableAdminUpgradeabilityProxy.sol";
import {BaseTest} from "./base/BaseTest.sol";
import {AaveStreamingTreasuryV1} from "../AaveStreamingTreasuryV1.sol";
import {IAdminControlledTreasury} from "../interfaces/IAdminControlledTreasury.sol";
import {ISablier} from "../interfaces/ISablier.sol";
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

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {
        _initNewCollectorOnProxy();
    }

    function testCreation() public {
        _Creation_validate(
            AaveStreamingTreasuryV1(address(COLLECTOR_V2_PROXY))
        );
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
            WETH,
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
            WETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.expectRevert(bytes("stream to the contract itself"));
        treasuryProxy.createStream(
            address(treasuryProxy),
            6 ether,
            WETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.expectRevert(bytes("stream to the caller"));
        treasuryProxy.createStream(
            address(CONTROLLER_OF_COLLECTOR),
            6 ether,
            WETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );

        // Deposits need to be more than 0, more than duration in seconds and multiple of duration
        vm.expectRevert(bytes("deposit is zero"));
        treasuryProxy.createStream(
            RECIPIENT_STREAM_1,
            0,
            WETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.expectRevert(bytes("deposit smaller than time delta"));
        treasuryProxy.createStream(
            RECIPIENT_STREAM_1,
            59,
            WETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        vm.expectRevert(bytes("deposit not multiple of time delta"));
        treasuryProxy.createStream(
            RECIPIENT_STREAM_1,
            61,
            WETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );

        // Start/stop times need to be consistent: start more than current current, stop later than start
        vm.expectRevert(bytes("start time before block.timestamp"));
        treasuryProxy.createStream(
            RECIPIENT_STREAM_1,
            6 ether,
            WETH,
            block.timestamp - 10,
            (block.timestamp + 10) + 60
        );
        vm.expectRevert(bytes("stop time before the start time"));
        treasuryProxy.createStream(
            RECIPIENT_STREAM_1,
            6 ether,
            WETH,
            block.timestamp + 10,
            block.timestamp
        );

        vm.expectEmit(true, true, true, true);
        emit CreateStream(
            100000,
            address(treasuryProxy),
            RECIPIENT_STREAM_1,
            6 ether,
            WETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        uint256 streamId = treasuryProxy.createStream(
            RECIPIENT_STREAM_1,
            6 ether,
            WETH,
            block.timestamp + 10,
            (block.timestamp + 10) + 60
        );
        require(streamId == 100000, "INVALID_STREAM_ID");

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

        require(sender == address(treasuryProxy), "INVALID_SENDER");
        require(recipient == RECIPIENT_STREAM_1, "INVALID_RECIPIENT");
        require(deposit == 6 ether, "INVALID_DEPOSIT");
        require(tokenAddress == WETH, "INVALID_ASSET");
        require(startTime == block.timestamp + 10, "INVALID_STARTTIME");
        require(stopTime == (block.timestamp + 10) + 60, "INVALID_STOPTIME");
        require(remainingBalance == 6 ether, "INVALID_REMAINING_BALANCE");
        require(ratePerSecond == 6 ether / 60, "INVALID_RATE_PER_SECOND");
        require(
            treasuryProxy.nextStreamId() == streamId + 1,
            "INVALID_NEXT_STREAM_ID"
        );
    }
}
