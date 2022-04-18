// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {Ownable} from "./libs/Ownable.sol";
import {IStreamable} from "./interfaces/IStreamable.sol";
import {IAdminControlledTreasury} from "./interfaces/IAdminControlledTreasury.sol";
import {IERC20} from "./interfaces/IERC20.sol";

contract ControllerOfCollectorForStreaming is Ownable {
    address public immutable COLLECTOR;

    constructor(address aaveGovShortTimelock, address collectorProxy) {
        COLLECTOR = collectorProxy;
        transferOwnership(aaveGovShortTimelock);
    }

    function approve(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        IAdminControlledTreasury(COLLECTOR).approve(token, recipient, amount);
    }

    function transfer(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        IAdminControlledTreasury(COLLECTOR).transfer(token, recipient, amount);
    }

    function createStream(
        address recipient,
        uint256 deposit,
        address tokenAddress,
        uint256 startTime,
        uint256 stopTime
    ) external onlyOwner returns (uint256) {
        return
            IStreamable(COLLECTOR).createStream(
                recipient,
                deposit,
                tokenAddress,
                startTime,
                stopTime
            );
    }

    function withdrawFromStream(uint256 streamId, uint256 funds)
        external
        onlyOwner
        returns (bool)
    {
        return IStreamable(COLLECTOR).withdrawFromStream(streamId, funds);
    }

    function cancelStream(uint256 streamId) external onlyOwner returns (bool) {
        return IStreamable(COLLECTOR).cancelStream(streamId);
    }
}
