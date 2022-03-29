// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.11;

import {IERC20} from "../interfaces/IERC20.sol";
import {VersionedInitializable} from "./VersionedInitializable.sol";

/**
 * @title AdminControlledTreasury
 * @notice Stores ERC20 tokens, and allows to dispose of them via approval or transfer dynamics
 * Adapted to be an implementation of a transparent proxy
 * @author BGD Labs
 **/
contract AdminControlledTreasury is VersionedInitializable {
    event NewFundsAdmin(address indexed fundsAdmin);

    address internal _fundsAdmin;

    uint256 public constant REVISION = 3;

    function getRevision() internal pure override returns (uint256) {
        return REVISION;
    }

    function getFundsAdmin() external view returns (address) {
        return _fundsAdmin;
    }

    modifier onlyFundsAdmin() {
        require(msg.sender == _fundsAdmin, "ONLY_BY_FUNDS_ADMIN");
        _;
    }

    function approve(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyFundsAdmin {
        token.approve(recipient, amount);
    }

    function transfer(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyFundsAdmin {
        token.transfer(recipient, amount);
    }

    function setFundsAdmin(address admin) public onlyFundsAdmin {
        _setFundsAdmin(admin);
    }

    function _setFundsAdmin(address admin) internal {
        _fundsAdmin = admin;
        emit NewFundsAdmin(admin);
    }
}
