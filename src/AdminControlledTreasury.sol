// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.11;

import {IERC20} from "./interfaces/IERC20.sol";
import {VersionedInitializable} from "./libs/VersionedInitializable.sol";
import {SafeERC20} from "./libs/SafeERC20.sol";
import {ReentrancyGuard} from "./libs/ReentrancyGuard.sol";

/**
 * @title AdminControlledTreasury v4
 * @dev Done abstract to add an `initialize()` function on the child, with `initializer` modifier
 * @notice Stores ERC20 tokens, and allows to dispose of them via approval or transfer dynamics
 * Adapted to be an implementation of a transparent proxy
 * @author BGD Labs
 **/
abstract contract AdminControlledTreasury is VersionedInitializable {
    using SafeERC20 for IERC20;

    event NewFundsAdmin(address indexed fundsAdmin);

    address internal _fundsAdmin;

    uint256 public constant REVISION = 4;

    /// @dev Used as reference address for outflows of ETH
    address public constant ETH_MOCK_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

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
        token.safeApprove(recipient, amount);
    }

    function transfer(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyFundsAdmin {
        if (address(token) == ETH_MOCK_ADDRESS) {
            (bool success, ) = recipient.call{value: amount}("");
            require(success, "REVERTED_ETH_TRANSFER");
        } else {
            token.safeTransfer(recipient, amount);
        }
    }

    function _setFundsAdmin(address admin) internal {
        _fundsAdmin = admin;
        emit NewFundsAdmin(admin);
    }

    /// @dev needed in order to receive ETH from the Aave v1 treasury
    receive() external payable {}
}
