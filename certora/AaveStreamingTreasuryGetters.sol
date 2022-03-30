// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.11;

import {IERC20} from "../src/interfaces/IERC20.sol";
import {ISablier} from "../src/interfaces/ISablier.sol";
import {AdminControlledTreasury} from "../src/libs/AdminControlledTreasury.sol";
import {ReentrancyGuard} from "../src/libs/ReentrancyGuard.sol";
import {SafeERC20} from "../src/libs/SafeERC20.sol";

/**
 * @title AaveStreamingTreasuryV1
 * @notice Stores ERC20 tokens of a treasury, adding streaming capabilities.
 * Modification of Sablier https://github.com/sablierhq/sablier/blob/develop/packages/protocol/contracts/Sablier.sol
 * Original can be found also deployed on https://etherscan.io/address/0xCD18eAa163733Da39c232722cBC4E8940b1D8888
 * Modifications:
 * - Sablier "pulls" the funds from the creator of the stream at creation. In the Aave case, we already have the funds.
 * - Anybody can create streams on Sablier. Here, only the funds admin (Aave governance via controller) can
 * - Adapted codebase to Solidity 0.8.11, mainly removing SafeMath and CarefulMath to use native safe math
 * - Same as with creation, on Sablier the `sender` and `recipient` can cancel a stream. Here, only fund admin and recipient
 * @author BGD Labs
 **/

/**
* Getters (view functions) needed for Certora spec
* 1. getStreamExists(uint256 streamId) - returns isEntity (boolean) for any given stream id
**/


contract AaveStreamingTreasuryV1 is
    AdminControlledTreasury,
    ReentrancyGuard,
    ISablier
{
    using SafeERC20 for IERC20;

    /*** Storage Properties ***/

    /**
     * @notice Counter for new stream ids.
     */
    uint256 public nextStreamId;

    /**
     * @notice The stream objects identifiable by their unsigned integer ids.
     */
    mapping(uint256 => Stream) private streams;

    /*** Modifiers ***/

    /**
     * @dev Throws if the caller is not the funds admin of the recipient of the stream.
     */
    modifier onlyAdminOrRecipient(uint256 streamId) {
        require(
            msg.sender == _fundsAdmin ||
                msg.sender == streams[streamId].recipient,
            "caller is not the funds admin or the recipient of the stream"
        );
        _;
    }

    /**
     * @dev Throws if the provided id does not point to a valid stream.
     */
    modifier streamExists(uint256 streamId) {
        require(streams[streamId].isEntity, "stream does not exist");
        _;
    }

    /*** Contract Logic Starts Here */

    constructor() {
        nextStreamId = 100000;
    }

    /*** View Functions ***/

    /**
     * @notice Returns the stream with all its properties.
     * @dev Throws if the id does not point to a valid stream.
     * @param streamId The id of the stream to query.
     * @notice Returns the stream object.
     */
    function getStream(uint256 streamId)
        external
        view
        streamExists(streamId)
        returns (
            address sender,
            address recipient,
            uint256 deposit,
            address tokenAddress,
            uint256 startTime,
            uint256 stopTime,
            uint256 remainingBalance,
            uint256 ratePerSecond
        )
    {
        sender = streams[streamId].sender;
        recipient = streams[streamId].recipient;
        deposit = streams[streamId].deposit;
        tokenAddress = streams[streamId].tokenAddress;
        startTime = streams[streamId].startTime;
        stopTime = streams[streamId].stopTime;
        remainingBalance = streams[streamId].remainingBalance;
        ratePerSecond = streams[streamId].ratePerSecond;
    }

    /**
     * @notice Returns either the delta in seconds between `block.timestamp` and `startTime` or
     *  between `stopTime` and `startTime, whichever is smaller. If `block.timestamp` is before
     *  `startTime`, it returns 0.
     * @dev Throws if the id does not point to a valid stream.
     * @param streamId The id of the stream for which to query the delta.
     * @notice Returns the time delta in seconds.
     */
    function deltaOf(uint256 streamId)
        public
        view
        streamExists(streamId)
        returns (uint256 delta)
    {
        Stream memory stream = streams[streamId];
        if (block.timestamp <= stream.startTime) return 0;
        if (block.timestamp < stream.stopTime)
            return block.timestamp - stream.startTime;
        return stream.stopTime - stream.startTime;
    }

    struct BalanceOfLocalVars {
        uint256 recipientBalance;
        uint256 withdrawalAmount;
        uint256 senderBalance;
    }

    /**
     * @notice Returns the available funds for the given stream id and address.
     * @dev Throws if the id does not point to a valid stream.
     * @param streamId The id of the stream for which to query the balance.
     * @param who The address for which to query the balance.
     * @notice Returns the total funds allocated to `who` as uint256.
     */
    function balanceOf(uint256 streamId, address who)
        public
        view
        streamExists(streamId)
        returns (uint256 balance)
    {
        Stream memory stream = streams[streamId];
        BalanceOfLocalVars memory vars;

        uint256 delta = deltaOf(streamId);
        vars.recipientBalance = delta * stream.ratePerSecond;

        /*
         * If the stream `balance` does not equal `deposit`, it means there have been withdrawals.
         * We have to subtract the total amount withdrawn from the amount of money that has been
         * streamed until now.
         */
        if (stream.deposit > stream.remainingBalance) {
            vars.withdrawalAmount = stream.deposit - stream.remainingBalance;
            vars.recipientBalance =
                vars.recipientBalance -
                vars.withdrawalAmount;
        }

        if (who == stream.recipient) return vars.recipientBalance;
        if (who == stream.sender) {
            vars.senderBalance =
                stream.remainingBalance -
                vars.recipientBalance;
            return vars.senderBalance;
        }
        return 0;
    }

    // certora getter
    function getStreamExists(uint256 streamId) public view returns (bool) {
        return streams[streamId].isEntity;
    }

    /*** Public Effects & Interactions Functions ***/

    struct CreateStreamLocalVars {
        uint256 duration;
        uint256 ratePerSecond;
    }

    /**
     * @notice Creates a new stream funded by this contracts itself and paid towards `recipient`.
     * @dev Throws if the recipient is the zero address, the contract itself or the caller.
     *  Throws if the deposit is 0.
     *  Throws if the start time is before `block.timestamp`.
     *  Throws if the stop time is before the start time.
     *  Throws if the duration calculation has a math error.
     *  Throws if the deposit is smaller than the duration.
     *  Throws if the deposit is not a multiple of the duration.
     *  Throws if the rate calculation has a math error.
     *  Throws if the next stream id calculation has a math error.
     *  Throws if the contract is not allowed to transfer enough tokens.
     *  Throws if there is a token transfer failure.
     * @param recipient The address towards which the money is streamed.
     * @param deposit The amount of money to be streamed.
     * @param tokenAddress The ERC20 token to use as streaming currency.
     * @param startTime The unix timestamp for when the stream starts.
     * @param stopTime The unix timestamp for when the stream stops.
     * @notice Returns the uint256 id of the newly created stream.
     */
    function createStream(
        address recipient,
        uint256 deposit,
        address tokenAddress,
        uint256 startTime,
        uint256 stopTime
    ) public onlyFundsAdmin returns (uint256) {
        require(recipient != address(0x00), "stream to the zero address");
        require(recipient != address(this), "stream to the contract itself");
        require(recipient != msg.sender, "stream to the caller");
        require(deposit > 0, "deposit is zero");
        require(
            startTime >= block.timestamp,
            "start time before block.timestamp"
        );
        require(stopTime > startTime, "stop time before the start time");

        CreateStreamLocalVars memory vars;
        vars.duration = stopTime - startTime;

        /* Without this, the rate per second would be zero. */
        require(deposit >= vars.duration, "deposit smaller than time delta");

        /* This condition avoids dealing with remainders */
        require(
            deposit % vars.duration == 0,
            "deposit not multiple of time delta"
        );

        vars.ratePerSecond = deposit / vars.duration;

        /* Create and store the stream object. */
        uint256 streamId = nextStreamId;
        streams[streamId] = Stream({
            remainingBalance: deposit,
            deposit: deposit,
            isEntity: true,
            ratePerSecond: vars.ratePerSecond,
            recipient: recipient,
            sender: address(this),
            startTime: startTime,
            stopTime: stopTime,
            tokenAddress: tokenAddress
        });

        /* Increment the next stream id. */
        nextStreamId++;

        emit CreateStream(
            streamId,
            address(this),
            recipient,
            deposit,
            tokenAddress,
            startTime,
            stopTime
        );
        return streamId;
    }

    /**
     * @notice Withdraws from the contract to the recipient's account.
     * @dev Throws if the id does not point to a valid stream.
     *  Throws if the caller is not the funds admin or the recipient of the stream.
     *  Throws if the amount exceeds the available balance.
     *  Throws if there is a token transfer failure.
     * @param streamId The id of the stream to withdraw tokens from.
     * @param amount The amount of tokens to withdraw.
     */
    function withdrawFromStream(uint256 streamId, uint256 amount)
        external
        nonReentrant
        streamExists(streamId)
        onlyAdminOrRecipient(streamId)
        returns (bool)
    {
        require(amount > 0, "amount is zero");
        Stream memory stream = streams[streamId];

        uint256 balance = balanceOf(streamId, stream.recipient);
        require(balance >= amount, "amount exceeds the available balance");

        streams[streamId].remainingBalance = stream.remainingBalance - amount;

        if (streams[streamId].remainingBalance == 0) delete streams[streamId];

        IERC20(stream.tokenAddress).safeTransfer(stream.recipient, amount);
        emit WithdrawFromStream(streamId, stream.recipient, amount);
        return true;
    }

    /**
     * @notice Cancels the stream and transfers the tokens back on a pro rata basis.
     * @dev Throws if the id does not point to a valid stream.
     *  Throws if the caller is not the funds admin or the recipient of the stream.
     *  Throws if there is a token transfer failure.
     * @param streamId The id of the stream to cancel.
     * @notice Returns bool true=success, otherwise false.
     */
    function cancelStream(uint256 streamId)
        external
        nonReentrant
        streamExists(streamId)
        onlyAdminOrRecipient(streamId)
        returns (bool)
    {
        Stream memory stream = streams[streamId];
        uint256 senderBalance = balanceOf(streamId, stream.sender);
        uint256 recipientBalance = balanceOf(streamId, stream.recipient);

        delete streams[streamId];

        IERC20 token = IERC20(stream.tokenAddress);
        if (recipientBalance > 0)
            // assumes contract holds the tokens.
            token.safeTransfer(stream.recipient, recipientBalance);

        emit CancelStream(
            streamId,
            stream.sender,
            stream.recipient,
            senderBalance,
            recipientBalance
        );
        return true;
    }
}
