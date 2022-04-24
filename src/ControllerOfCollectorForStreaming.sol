// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {Ownable} from "./libs/Ownable.sol";
import {IStreamable} from "./interfaces/IStreamable.sol";
import {IAdminControlledTreasury} from "./interfaces/IAdminControlledTreasury.sol";
import {IERC20} from "./interfaces/IERC20.sol";

contract ControllerOfCollectorForStreaming is Ownable {
    constructor(address aaveGovShortTimelock) {
        transferOwnership(aaveGovShortTimelock);
    }

    function approve(
        address collector,
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        IAdminControlledTreasury(collector).approve(token, recipient, amount);
    }

    function transfer(
        address collector,
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        IAdminControlledTreasury(collector).transfer(token, recipient, amount);
    }

    function createStream(
        address collector,
        address recipient,
        uint256 deposit,
        address tokenAddress,
        uint256 startTime,
        uint256 stopTime
    ) external onlyOwner returns (uint256) {
        return
            IStreamable(collector).createStream(
                recipient,
                deposit,
                tokenAddress,
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
