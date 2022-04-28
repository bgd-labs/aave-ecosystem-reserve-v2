import "erc20.spec"
using DummyERC20Impl as _asset

methods {
    createStream(address, uint256, address, uint256, uint256) returns (uint256)
    withdrawFromStream(uint256, uint256) returns (bool)
    cancelStream(uint256) returns (bool)
    getStreamExists(uint256) returns (bool) envfree
    getStream(uint256) returns (address, address, uint256, address, uint256, uint256, uint256, uint256) envfree
    _nextStreamId() returns (uint256) envfree
    balanceOf(uint256, address) returns (uint256) // not envfree - uses block timestamp
    deltaOf(uint256) returns (uint256) // not envfree - uses block timestamp
    getFundsAdmin() returns (address) envfree

    _asset.balanceOf(address) returns (uint256) envfree
}

///////////////////////////////////////////////////////////////////////////////////
// CVL Functions and Definitions
///////////////////////////////////////////////////////////////////////////////////

/*******************************
* Getters for stream properties
********************************/

function getStreamRemainingBalance(uint256 streamId) returns uint256 {
    address sender; address recipient; uint256 deposit; address tokenAddress;
    uint256 startTime; uint256 stopTime; uint256 remainingBalance; uint256 rps;
    sender, recipient, deposit, tokenAddress, startTime, stopTime, remainingBalance, rps = getStream(streamId);
    return remainingBalance;
}

function getStreamDeposit(uint256 streamId) returns uint256 {
    address sender; address recipient; uint256 deposit; address tokenAddress;
    uint256 startTime; uint256 stopTime; uint256 remainingBalance; uint256 rps;
    sender, recipient, deposit, tokenAddress, startTime, stopTime, remainingBalance, rps = getStream(streamId);
    return deposit;
}

function getStreamRPS(uint256 streamId) returns uint256 {
    address sender; address recipient; uint256 deposit; address tokenAddress;
    uint256 startTime; uint256 stopTime; uint256 remainingBalance; uint256 rps;
    sender, recipient, deposit, tokenAddress, startTime, stopTime, remainingBalance, rps = getStream(streamId);
    return rps;
}

function getStreamRecipient(uint256 streamId) returns address {
    address sender; address recipient; uint256 deposit; address tokenAddress;
    uint256 startTime; uint256 stopTime; uint256 remainingBalance; uint256 rps;
    sender, recipient, deposit, tokenAddress, startTime, stopTime, remainingBalance, rps = getStream(streamId);
    return recipient;
}


function getStreamSender(uint256 streamId) returns address {
    address sender; address recipient; uint256 deposit; address tokenAddress;
    uint256 startTime; uint256 stopTime; uint256 remainingBalance; uint256 rps;
    sender, recipient, deposit, tokenAddress, startTime, stopTime, remainingBalance, rps = getStream(streamId);
    return sender;
}

function getStreamStartTime(uint256 streamId) returns uint256 {
    address sender; address recipient; uint256 deposit; address tokenAddress;
    uint256 startTime; uint256 stopTime; uint256 remainingBalance; uint256 rps;
    sender, recipient, deposit, tokenAddress, startTime, stopTime, remainingBalance, rps = getStream(streamId);
    return startTime;
}

function getStreamStopTime(uint256 streamId) returns uint256 {
    address sender; address recipient; uint256 deposit; address tokenAddress;
    uint256 startTime; uint256 stopTime; uint256 remainingBalance; uint256 rps;
    sender, recipient, deposit, tokenAddress, startTime, stopTime, remainingBalance, rps = getStream(streamId);
    return stopTime;
}

function getStreamToken(uint256 streamId) returns address {
    address sender; address recipient; uint256 deposit; address tokenAddress;
    uint256 startTime; uint256 stopTime; uint256 remainingBalance; uint256 rps;
    sender, recipient, deposit, tokenAddress, startTime, stopTime, remainingBalance, rps = getStream(streamId);
    return tokenAddress;
}

// returns true iff the parameter f is one of the three public stream functions
function streamingTreasuryFunctions(method f) {
    require f.selector == createStream(address, uint256, address, uint256, uint256).selector ||
        f.selector == withdrawFromStream(uint256, uint256).selector ||
        f.selector == cancelStream(uint256).selector;
}

// checks the correctness of createStream parameters
function createStreamParamCheck(address recipient, uint256 start, uint256 stop, 
    uint256 deposit, address msgSender, uint256 blockTimestamp) returns bool {
    
    mathint duration = stop - start;
    if (duration <= 0) return false;
    return recipient != 0 && recipient != msgSender && recipient != currentContract &&
        start >= blockTimestamp && deposit >= duration && _nextStreamId() < max_uint256 &&
        deposit % duration == 0 && msgSender == getFundsAdmin();
}

///////////////////////////////////////////////////////////////////////////////////
// Invariants
///////////////////////////////////////////////////////////////////////////////////


/*
    @Rule

    @Description:
        Stream's remaining balance is always equal or less than the stream deposit

    @Formula:
        {
            stream.remainingBalance <= stream.deposit
        }

    @Notes:

    @Link:

*/
invariant remainingBalance_LE_deposit(uint256 streamId)
    getStreamExists(streamId) => getStreamRemainingBalance(streamId) <= getStreamDeposit(streamId)

/*
    @Rule

    @Description:
        stream's balanceOf() returns a value equal or less than stream's deposit
    @Formula:
        {
            balanceOf(stream, alice) <= stream.deposit
        }

    @Notes:

    @Link:
    
*/
invariant balanceOf_LE_deposit(env e, uint256 streamId)
    getStreamExists(streamId) => balanceOf(e, streamId, getStreamRecipient(streamId)) <= getStreamDeposit(streamId)

// For all streams, ratePerSecond >= 1
/*
    @Rule

    @Description:
        Stream's rate per second is always equal or greater than 1

    @Formula:
        {
            stream.ratePerSecond >= 1
        }

    @Notes:

    @Link:
    
*/
invariant ratePerSecond_GE_1(uint256 streamId)
    getStreamExists(streamId) => getStreamRPS(streamId) >= 1


/*
    @Rule

    @Description:
        Recipient cannot withdraw before start time

    @Formula:
        {
            stream.startTime >= block.timestamp => balanceOf(stream, recipient) == 0
        }

    @Notes:

    @Link:

*/
invariant cantWithdrawTooEarly(env e, uint256 streamId)
    getStreamExists(streamId) && e.block.timestamp <= getStreamStartTime(streamId) =>
        balanceOf(e, streamId, getStreamRecipient(streamId)) == 0

/*
    @Rule

    @Description:
        Every stream has a sender and a recipient

    @Formula:
        {
            stream.isEntity => stream.sender != 0 && stream.recipient != 0
        }

    @Notes:

    @Link:

*/
invariant streamHasSenderAndRecipient(uint256 streamId)
    getStreamExists(streamId) => getStreamRecipient(streamId) != 0 && getStreamSender(streamId) != 0

// accumulator for a  sum of all the withdrawals per stream
ghost mapping(uint256 => mathint) sumWithdrawalsPerStream {
    init_state axiom forall uint256 t. sumWithdrawalsPerStream[t] == 0;
}

/*
 RemainingBalance is updated as a result of a withdrawal. 
 We calculate the withdrawal amount and add it to the withdrawals accumulator
 */
hook Sstore _streams[KEY uint256 id].remainingBalance uint256 balance
    (uint256 old_balance) STORAGE {
        sumWithdrawalsPerStream[id] = sumWithdrawalsPerStream[id] + 
            to_mathint(old_balance) - to_mathint(balance);
    }

/*
    @Rule

    @Description:
        Sum of all withdrawals from a stream is equal or less than the original stream deposit

    @Formula:
        {
            Σ(stream withdrawals) <= stream.deposit
        }

    @Notes:

    @Link:

*/
invariant withdrawalsSolvent(uint256 streamId)
    to_mathint(getStreamRemainingBalance(streamId)) == 
        (to_mathint(getStreamDeposit(streamId)) - sumWithdrawalsPerStream[streamId])
    // filter out createStream because it resets the deposit value
    filtered { f-> f.selector != createStream(address, uint256, address, uint256, uint256).selector }

///////////////////////////////////////////////////////////////////////////////////
// Rules
///////////////////////////////////////////////////////////////////////////////////

/*
    @Rule

    @Description:
        Next Stream ID only goes up

    @Formula:
        {
            nextIdBefore = _nextStreamId()
        }
        <
            f(e, args)
        >
        {
            _nextStreamId() >= nextIdBefore
        }

    @Notes:


    @Link:

*/
rule _nextStreamIdCorrectness(method f)
filtered { f-> f.selector != initialize(address).selector} 
{
    env e;
    calldataarg args;
    uint256 _nextStreamIdBefore = _nextStreamId();

    f(e, args);

    uint256 _nextStreamIdAfter = _nextStreamId();
    assert _nextStreamIdAfter >= _nextStreamIdBefore;
}

/*
    @Rule

    @Description:
        Existing stream's remaining balance can only decrease

    @Formula:
        {
            remainingBalancebefore = stream.remainingBalance
        }
        <
            f(e, args)
        >
        {
            stream.remainingBalance <= remainingBalanceBefore
        }

    @Notes:


    @Link:

*/
rule streamRemainingBalanceMonotonicity(method f, uint256 streamId) {
    env e;
    calldataarg args;
    
    require getStreamExists(streamId);

    // without this prover creates a new stream with the same id as the current one
    require _nextStreamId() > streamId;

    uint256 remainingBalanceBefore = getStreamRemainingBalance(streamId);

    f(e, args);

    uint256 remainingBalanceAfter = getStreamRemainingBalance(streamId);
    assert remainingBalanceAfter <= remainingBalanceBefore;
}

/*
    @Rule

    @Description:
        Recipient cannot withdraw more than the current balance

    @Formula:
        {
            amount > balanceOf(stream, msg.sender)
        }
        <
            withdrawFromStream(stream, amount)
        >
        {
            lastReverted
        }

    @Notes:


    @Link:

*/
rule integrityOfWithdraw(uint256 streamId, uint256 amount) {
    env e;

    address recipient = getStreamRecipient(streamId);
    require e.msg.sender == recipient;

    uint256 balanceBefore = balanceOf(e, streamId, recipient);

    require amount > balanceBefore;
    withdrawFromStream@withrevert(e, streamId, amount);
    bool reverted = lastReverted;

    assert reverted;
}


/*
    @Rule

    @Description:
        Withdrawing full balance is always possible if treasury has sufficient token balance

    @Formula:
        {
            balance = balanceOf(stream, msg.sender)
        }
        <
            withdrawFromStream(stream, balance)
        >
        {
            !lastReverted
        }

    @Notes:

    @Link:

*/
rule fullWithdrawPossible(uint256 streamId) {
    env e;
    require getStreamExists(streamId);
    address recipient = getStreamRecipient(streamId);
    require e.msg.sender == recipient;
    require e.msg.sender != currentContract;
    uint256 balance = balanceOf(e, streamId, recipient);
    require balance > 0 && balance <= getStreamRemainingBalance(streamId);
    require _asset.balanceOf(currentContract) >= balance;
    require to_mathint(_asset.balanceOf(e.msg.sender)) + to_mathint(balance) < max_uint256;

    withdrawFromStream@withrevert(e, streamId, balance);

    assert !lastReverted;    
}

/*
    @Rule

    @Description:
        deltaOf() returns a correct value

    @Formula:
        {
            stream.stopTime > stream.startTime
            stream.isEntity
        }
        <
            delta = deltaOf(stream)
        >
        {
            start >= block.timestamp => delta == 0
            block.timestamp > start && stop >= block.timestamp => delta == block.timestamp - start
            block.timestamp > stop => delta == stop - start
        }

    @Notes:

    @Link:

*/
rule deltaOfCorrectness(uint256 streamId) {
    env e;
    require e.msg.value == 0;
    uint256 start = getStreamStartTime(streamId);
    uint256 stop = getStreamStopTime(streamId);
    require stop > start;

    uint256 delta = deltaOf@withrevert(e, streamId);
    assert lastReverted => !getStreamExists(streamId);

    assert start >= e.block.timestamp => delta == 0;
    assert e.block.timestamp > start && stop >= e.block.timestamp => delta == e.block.timestamp - start;
    assert e.block.timestamp > stop => delta == stop - start;
}

/*
    @Rule

    @Description:
        createStream() succeeds if parameters are valid

    @Formula:
        {
            createStreamParamCheck(params) == true
        }
        <
            createStream(params)
        >
        {
            !lastReverted
        }

    @Notes:

    @Link:

*/
rule createStreamCorrectness(address recipient, uint256 deposit, address tokenAddress, 
    uint256 startTime, uint256 stopTime) {

    env e;
    require e.msg.value == 0;
    bool paramCheck = createStreamParamCheck(recipient, startTime, stopTime, deposit, e.msg.sender, e.block.timestamp);
    createStream@withrevert(e, recipient, deposit, tokenAddress, startTime, stopTime);

    assert lastReverted <=> !paramCheck;
}

/*
    @Rule

    @Description:
        after cancelStream() is called, stream is deleted

    @Formula:
        {
            stream.isEntity == true
        }
        <
            cancelStream(stream)
        >
        {
            stream.isEntity == false
        }

    @Notes:


    @Link:

*/
rule noStreamAfterCancel(uint256 streamId) {
    env e;

    require getStreamExists(streamId);
    cancelStream(e, streamId);
    assert !getStreamExists(streamId);
}

/*
    @Rule

    @Description:
        Stream's remaining balance after any operation

    @Formula:


    @Notes:


    @Link:

*/
rule zeroRemainingBalanceDeleted(method f, uint256 streamId) {
    env e;
    calldataarg args;

    uint256 balanceBefore = getStreamRemainingBalance(streamId);
    require balanceBefore > 0;

    f(e, args);

    uint256 balanceAfter = getStreamRemainingBalance(streamId);
    assert balanceAfter > 0;

}

/*
    @Rule

    @Description:
        If withdraw is available for one stream, it's also available for another stream, provided treasury balance
        is sufficient. This is a way to check that withdrawal is available.

    @Formula:
        {
            amount1 <= balanceOf(stream1, msg.sender)
            amount2 <= balanceOf(stream2, msg.sender)
            tokenBalance = token.balanceOf(currentContract)
        }
        <
            withdrawFromStream(stream1, amount1) without revert
            withdrawFromStream(stream2, amount2) at init
        >
        {
            lastReverted => tokenBalance < amount2
        }


    @Notes:

    @Link:

*/
rule withdrawAvailable(uint256 stream1, uint256 stream2, uint256 amount1, uint256 amount2 ) {
    env e1;
    env e2;
    storage init = lastStorage;
    uint256 tokenBalance = _asset.balanceOf(currentContract);

    require currentContract != e1.msg.sender && currentContract != e2.msg.sender;
    withdrawFromStream(e1, stream1, amount1);

    require getStreamExists(stream2);
    require e2.msg.sender == getStreamRecipient(stream2) && e2.msg.sender != 0;
    uint256 balanceRecipient2 = balanceOf(e2, stream2, e2.msg.sender);
    require balanceRecipient2 <= getStreamDeposit(stream2);
    require amount2 <= balanceRecipient2 && amount2 > 0;
    require to_mathint(amount2) + to_mathint(_asset.balanceOf(e2.msg.sender)) < max_uint256;

    withdrawFromStream@withrevert(e2, stream2, amount2) at init;

    uint256 tokenBalanceAfter2 = _asset.balanceOf(currentContract);

    assert lastReverted => tokenBalance < amount2;
}

/*
    @Rule

    @Description:
        Treasury balance can decrease appropriately only on withdrawFromStream and cancelStream()

    @Formula:
        {
            treasuryBalanceBefore = token.balanceOf(currentContract)
            recipientBalance = balanceOf(stream, msg.sender)
            amount <= recipientBalance
        }
        <
            withdrawFromStream(stream, amount) or cancelStream(stream)
        >
        {
           token.balanceOf(currentContract) - treasuryBalanceBefore <= recipientBalance
        }

    @Notes:

    @Link:

*/
rule treasuryBalanceCorrectness(method f, uint256 streamId) {
    env e;

    streamingTreasuryFunctions(f);
    require getStreamRecipient(streamId) == e.msg.sender;
    uint256 treasuryBalanceBefore = _asset.balanceOf(currentContract);
    uint256 recipientBalanceBefore = balanceOf(e, streamId, e.msg.sender);

    if (f.selector == withdrawFromStream(uint256, uint256).selector) {
        uint256 amount;
        withdrawFromStream(e, streamId, amount);
    } else if (f.selector == cancelStream(uint256).selector) {
        cancelStream(e, streamId);
    } else {

        calldataarg args;
        f(e, args);
    }

    uint256 treasuryBalanceAfter = _asset.balanceOf(currentContract);

    assert treasuryBalanceBefore - treasuryBalanceAfter <= recipientBalanceBefore;
}

rule onlyFundAdminCanCreate(address recipient, uint256 deposit, address token, uint256 start, uint256 end) {
    env e;

    createStream@withrevert(e, recipient, deposit, token, start, end);
    bool reverted = lastReverted;
    assert !reverted => e.msg.sender == getFundsAdmin();

}