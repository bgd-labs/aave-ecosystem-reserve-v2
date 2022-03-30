import "erc20.spec"
using DummyERC20Impl as _asset

methods {
    createStream(address, uint256, address, uint256, uint256) returns (uint256)
    withdrawFromStream(uint256, uint256) returns (bool)
    cancelStream(uint256) returns (bool)
    getStreamExists(uint256) returns (bool) envfree
    getStream(uint256) returns (address, address, uint256, address, uint256, uint256, uint256, uint256) envfree
    nextStreamId() returns (uint256) envfree
    balanceOf(uint256, address) returns (uint256) // not envfree - uses block timestamp
    deltaOf(uint256) returns (uint256) // not envfree - uses block timestamp
    getFundsAdmin() returns (address) envfree

    _asset.balanceOf(address) returns (uint256) envfree
}

///////////////////////////////////////////////////////////////////////////////////
// CVL Functions
///////////////////////////////////////////////////////////////////////////////////

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

// ghost nextGhost() returns uint256{
//     init_state axiom nextGhost() == 100000;
// }


// hook Sstore nextStreamId uint256 newStreamId STORAGE {
//   havoc nextGhost assuming nextGhost@new() == newStreamId;
// }

// // fails
// invariant noNextStreamIdExists()
//     !getStreamExists(nextStreamId())

///////////////////////////////////////////////////////////////////////////////////
// Invariants
///////////////////////////////////////////////////////////////////////////////////


// For all streams, remaining balance <= deposit.
invariant remainingBalance_LE_deposit(uint256 streamId)
    getStreamExists(streamId) => getStreamRemainingBalance(streamId) <= getStreamDeposit(streamId)

invariant balanceOf_LE_deposit(env e, uint256 streamId)
    getStreamExists(streamId) => balanceOf(e, streamId, getStreamRecipient(streamId)) <= getStreamDeposit(streamId)

// For all streams, ratePerSecond >= 1
invariant ratePerSecond_GE_1(uint256 streamId)
    getStreamExists(streamId) => getStreamRPS(streamId) >= 1

// For all streams, recipient can't withdraw anything before start time is reached.
invariant cantWithdrawTooEarly(env e, uint256 streamId)
    getStreamExists(streamId) && e.block.timestamp <= getStreamStartTime(streamId) =>
        balanceOf(e, streamId, getStreamRecipient(streamId)) == 0

///////////////////////////////////////////////////////////////////////////////////
// Rules
///////////////////////////////////////////////////////////////////////////////////

// nextStreamId up only
rule nextStreamIdCorrectness(method f) {
    env e;
    calldataarg args;
    uint256 nextStreamIdBefore = nextStreamId();

    f(e, args);

    uint256 nextStreamIdAfter = nextStreamId();
    assert nextStreamIdAfter >= nextStreamIdBefore;
}

// stream's remaining balance can only go down.
rule streamRemainingBalanceMonotonicity(method f, uint256 streamId) {
    env e;
    calldataarg args;
    
    require getStreamExists(streamId);

    // without this prover creates a new stream with the same id as the current one
    require nextStreamId() > streamId;

    uint256 remainingBalanceBefore = getStreamRemainingBalance(streamId);

    f(e, args);

    uint256 remainingBalanceAfter = getStreamRemainingBalance(streamId);
    assert remainingBalanceAfter <= remainingBalanceBefore;
}

// can't withdraw more than current balance.
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

// withdraw is always possible: if user can withdraw x, they can withdraw their whole balanceOf.
// assuming contract has all the tokens (max uint)
rule fullWithdrawPossible(uint256 streamId) {
    env e;
    require getStreamExists(streamId);
    address recipient = getStreamRecipient(streamId);
    uint256 balance = balanceOf(e, streamId, recipient);

    withdrawFromStream@withrevert(e, streamId, balance);

    assert !lastReverted;    
}

// deltaOf() correctness 
//     block.timeStamp <= stream.startTime => delta = 0
//     block.timeStamp <= stream.stopTime => delta = stream.stopTime - stream.startTime
//     block.timeStamp > stream.stopTime => delta = block.stopTime - block.startTime
//     deltaOf() reverts if stream doesn't exist (isEntity == false)
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
2. createStream():
    - recipient is not 0, msg.sender or the contract.
    - startTime >= block.timestamp
    - duration > 0 (equivalent to stopTime - startTime > 0)
    - deposit >= duration
    - ratePerSecond = deposit / duration
    - deposit is a multiple of duration (no remainders)
*/
function createStreamParamCheck(address recipient, uint256 start, uint256 stop, 
    uint256 deposit, address msgSender, uint256 blockTimestamp) returns bool {
    
    mathint duration = stop - start;
    if (duration <= 0) return false;
    return recipient != 0 && recipient != msgSender && recipient != currentContract &&
        start >= blockTimestamp && deposit >= duration && nextStreamId() < max_uint256 &&
        deposit % duration == 0 && msgSender == getFundsAdmin();
}

rule createStreamCorrectness(address recipient, uint256 deposit, address tokenAddress, 
    uint256 startTime, uint256 stopTime) {

    env e;
    require e.msg.value == 0;
    // require e.msg.sender == getFundsAdmin();
    bool paramCheck = createStreamParamCheck(recipient, startTime, stopTime, deposit, e.msg.sender, e.block.timestamp);
    createStream@withrevert(e, recipient, deposit, tokenAddress, startTime, stopTime);


    assert lastReverted <=> !paramCheck;
}