// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {IERC20} from "./IERC20.sol";

interface IAaveEcosystemReserveController {
    function approve(
        address collector,
        IERC20 token,
        address recipient,
        uint256 amount
    ) external;

    function transfer(
        address collector,
        IERC20 token,
        address recipient,
        uint256 amount
    ) external;

    function createStream(
        address collector,
        address recipient,
        uint256 deposit,
        IERC20 tokenAddress,
        uint256 startTime,
        uint256 stopTime
    ) external;

    function withdrawFromStream(
        address collector,
        uint256 streamId,
        uint256 funds
    ) external;

    function cancelStream(address collector, uint256 streamId) external;
}
