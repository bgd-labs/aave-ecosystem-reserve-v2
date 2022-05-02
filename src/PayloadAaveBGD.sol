// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {IAaveEcosystemReserveController} from "./interfaces/IAaveEcosystemReserveController.sol";
import {IStreamable} from "./interfaces/IStreamable.sol";
import {IInitializableAdminUpgradeabilityProxy} from "./interfaces/IInitializableAdminUpgradeabilityProxy.sol";
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

    IAaveEcosystemReserveController public constant CONTROLLER_OF_COLLECTOR =
        IAaveEcosystemReserveController(
            0x3d569673dAa0575c936c7c67c4E6AedA69CC630C
        );

    IStreamable public constant ECOSYSTEM_RESERVE_V2_IMPL =
        IStreamable(0x1aa435ed226014407Fa6b889e9d06c02B1a12AF3);

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

    address public constant BGD_RECIPIENT =
        0xb812d0944f8F581DfAA3a93Dda0d22EcEf51A9CF;

    function execute() external {
        // Upgrade of both treasuries' implementation
        // We use a common implementation for both ecosystem's reserves
        COLLECTOR_V2_PROXY.upgradeToAndCall(
            address(ECOSYSTEM_RESERVE_V2_IMPL),
            abi.encodeWithSelector(
                IStreamable.initialize.selector,
                address(CONTROLLER_OF_COLLECTOR)
            )
        );
        AAVE_TOKEN_COLLECTOR_PROXY.upgradeToAndCall(
            address(ECOSYSTEM_RESERVE_V2_IMPL),
            abi.encodeWithSelector(
                IStreamable.initialize.selector,
                address(CONTROLLER_OF_COLLECTOR)
            )
        );
        // We initialise the implementation, for security
        ECOSYSTEM_RESERVE_V2_IMPL.initialize(address(CONTROLLER_OF_COLLECTOR));

        // Transfer of the upfront payment, 40% of the total
        CONTROLLER_OF_COLLECTOR.transfer(
            address(COLLECTOR_V2_PROXY),
            AUSDC,
            BGD_RECIPIENT,
            AUSDC_UPFRONT_AMOUNT
        );
        CONTROLLER_OF_COLLECTOR.transfer(
            address(COLLECTOR_V2_PROXY),
            ADAI,
            BGD_RECIPIENT,
            ADAI_UPFRONT_AMOUNT
        );
        CONTROLLER_OF_COLLECTOR.transfer(
            address(COLLECTOR_V2_PROXY),
            AUSDT,
            BGD_RECIPIENT,
            AUSDT_UPFRONT_AMOUNT
        );
        CONTROLLER_OF_COLLECTOR.transfer(
            address(AAVE_TOKEN_COLLECTOR_PROXY),
            AAVE,
            BGD_RECIPIENT,
            AAVE_UPFRONT_AMOUNT
        );

        // Creation of the streams
        CONTROLLER_OF_COLLECTOR.createStream(
            address(COLLECTOR_V2_PROXY),
            BGD_RECIPIENT,
            AUSDC_STREAM_AMOUNT,
            AUSDC,
            block.timestamp,
            block.timestamp + STREAMS_DURATION
        );
        CONTROLLER_OF_COLLECTOR.createStream(
            address(AAVE_TOKEN_COLLECTOR_PROXY),
            BGD_RECIPIENT,
            AAVE_STREAM_AMOUNT,
            AAVE,
            block.timestamp,
            block.timestamp + STREAMS_DURATION
        );
    }
}
