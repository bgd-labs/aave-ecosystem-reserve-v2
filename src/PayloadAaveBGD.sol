// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {AaveEcosystemReserveController} from "./AaveEcosystemReserveController.sol";
import {AaveEcosystemReserveV2} from "./AaveEcosystemReserveV2.sol";
import {IInitializableAdminUpgradeabilityProxy} from "./interfaces/IInitializableAdminUpgradeabilityProxy.sol";
import {IStreamable} from "./interfaces/IStreamable.sol";
import {IAdminControlledEcosystemReserve} from "./interfaces/IAdminControlledEcosystemReserve.sol";
import {IERC20} from "./interfaces/IERC20.sol";

contract PayloadAaveBGD {
    IInitializableAdminUpgradeabilityProxy public constant COLLECTOR_V2_PROXY =
        IInitializableAdminUpgradeabilityProxy(
            0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c
        );

    IInitializableAdminUpgradeabilityProxy
        public constant AAVE_TOKEN_COLLECTOR_PROXY =
        IInitializableAdminUpgradeabilityProxy(
            0x25F2226B597E8F9514B3F68F00f494cF4f286491
        );

    address public constant GOV_SHORT_EXECUTOR =
        0xEE56e2B3D491590B5b31738cC34d5232F378a8D5;

    IERC20 public constant AUSDC =
        IERC20(0xBcca60bB61934080951369a648Fb03DF4F96263C);
    IERC20 public constant ADAI =
        IERC20(0x028171bCA77440897B824Ca71D1c56caC55b68A3);
    IERC20 public constant AUSDT =
        IERC20(0x3Ed3B47Dd13EC9a98b44e6204A523E766B225811);
    IERC20 public constant AAVE =
        IERC20(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);

    uint256 public constant AUSDC_UPFRONT_AMOUNT = 1200000 * 1e6; // 1'200'000 aUSDC
    uint256 public constant ADAI_UPFRONT_AMOUNT = 1000000 ether; // 1'000'000 aDAI
    uint256 public constant AUSDT_UPFRONT_AMOUNT = 1000000 * 1e6; // 1'000'000 aUSDT
    uint256 public constant AAVE_UPFRONT_AMOUNT = 8400 ether; // 8'400 AAVE

    uint256 public constant AUSDC_STREAM_AMOUNT = 4800008160000; // ~4'800'000 aUSDC. A bit more for the streaming requirements
    uint256 public constant AAVE_STREAM_AMOUNT = 12600000000000074880000; // ~12'600 AAVE. A bit more for the streaming requirements
    uint256 public constant STREAMS_DURATION = 450 days; // 15 months of 30 days

    /// IMPORTANT. This is a mock address, only used for tests of the payload. CHANGE IT BEFORE ANY USE IN PRODUCTION
    address public constant BGD_RECIPIENT =
        address(0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB);

    function execute() external {
        // We deploy only 1 new controller of collector, to use in common for the treasuries of the protocol and AAVE
        AaveEcosystemReserveController controllerOfCollector = new AaveEcosystemReserveController(
                GOV_SHORT_EXECUTOR
            );

        // New implementation of the ecosystem reserve, with streaming capabilities
        // Important to highlight that the REVISION used (4) is higher than the current one for both treasuries
        AaveEcosystemReserveV2 ecoReserveImpl = new AaveEcosystemReserveV2();

        // Upgrade of both treasuries' implementation
        COLLECTOR_V2_PROXY.upgradeToAndCall(
            address(ecoReserveImpl),
            abi.encodeWithSelector(
                IStreamable.initialize.selector,
                address(controllerOfCollector)
            )
        );
        AAVE_TOKEN_COLLECTOR_PROXY.upgradeToAndCall(
            address(ecoReserveImpl),
            abi.encodeWithSelector(
                IStreamable.initialize.selector,
                address(controllerOfCollector)
            )
        );
        // We initialise the implementation, for security
        ecoReserveImpl.initialize(address(controllerOfCollector));

        // Transfer of the upfront payment, 40% of the total
        controllerOfCollector.transfer(
            address(COLLECTOR_V2_PROXY),
            AUSDC,
            BGD_RECIPIENT,
            AUSDC_UPFRONT_AMOUNT
        );
        controllerOfCollector.transfer(
            address(COLLECTOR_V2_PROXY),
            ADAI,
            BGD_RECIPIENT,
            ADAI_UPFRONT_AMOUNT
        );
        controllerOfCollector.transfer(
            address(COLLECTOR_V2_PROXY),
            AUSDT,
            BGD_RECIPIENT,
            AUSDT_UPFRONT_AMOUNT
        );
        controllerOfCollector.transfer(
            address(AAVE_TOKEN_COLLECTOR_PROXY),
            AAVE,
            BGD_RECIPIENT,
            AAVE_UPFRONT_AMOUNT
        );

        // Creation of the streams
        controllerOfCollector.createStream(
            address(COLLECTOR_V2_PROXY),
            BGD_RECIPIENT,
            AUSDC_STREAM_AMOUNT,
            AUSDC,
            block.timestamp,
            block.timestamp + STREAMS_DURATION
        );
        controllerOfCollector.createStream(
            address(AAVE_TOKEN_COLLECTOR_PROXY),
            BGD_RECIPIENT,
            AAVE_STREAM_AMOUNT,
            AAVE,
            block.timestamp,
            block.timestamp + STREAMS_DURATION
        );
    }
}
