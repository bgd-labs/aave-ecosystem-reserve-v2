// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {Ownable} from "./libs/Ownable.sol";
import {IStreamable} from "./interfaces/IStreamable.sol";
import {IAdminControlledEcosystemReserve} from "./interfaces/IAdminControlledEcosystemReserve.sol";
import {IERC20} from "./interfaces/IERC20.sol";

contract AaveEcosystemReserveController is Ownable {
    constructor(address aaveGovShortTimelock) {
        transferOwnership(aaveGovShortTimelock);
    }

    function approve(
        address collector,
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        IAdminControlledEcosystemReserve(collector).approve(
            token,
            recipient,
            amount
        );
    }

    function transfer(
        address collector,
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        IAdminControlledEcosystemReserve(collector).transfer(
            token,
            recipient,
            amount
        );
    }

    function createStream(
        address collector,
        address recipient,
        uint256 deposit,
        IERC20 tokenAddress,
        uint256 startTime,
        uint256 stopTime
    ) external onlyOwner returns (uint256) {
        return
            IStreamable(collector).createStream(
                recipient,
                deposit,
                address(tokenAddress),
                startTime,
                stopTime
            );
    }

    function withdrawFromStream(
        address collector,
        uint256 streamId,
        uint256 funds
    ) external onlyOwner returns (bool) {
        return IStreamable(collector).withdrawFromStream(streamId, funds);
    }

    function cancelStream(address collector, uint256 streamId)
        external
        onlyOwner
        returns (bool)
    {
        return IStreamable(collector).cancelStream(streamId);
    }
}
