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

definition FirstStreamId() returns uint256 = 100000;

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

function streamingTreasuryFunctions(method f) {
    require f.selector == createStream(address, uint256, address, uint256, uint256).selector ||
        f.selector == withdrawFromStream(uint256, uint256).selector ||
        f.selector == cancelStream(uint256).selector;
}



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

// 6. isEntity => recipient != 0 && sender != 0
invariant streamHasSenderAndRecipient(uint256 streamId)
    getStreamExists(streamId) => getStreamRecipient(streamId) != 0 && getStreamSender(streamId) != 0

ghost mapping(uint256 => mathint) sumWithdrawalsPerStream {
    init_state axiom forall uint256 t. sumWithdrawalsPerStream[t] == 0;
}

hook Sstore streams[KEY uint256 id].remainingBalance uint256 balance
    (uint256 old_balance) STORAGE {
        sumWithdrawalsPerStream[id] = sumWithdrawalsPerStream[id] + 
            to_mathint(old_balance) - to_mathint(balance);
    }

// remaining balance is always the original deposit minus sum of all withdrawals
invariant withdrawalsSolvent(uint256 streamId)
    to_mathint(getStreamRemainingBalance(streamId)) == 
        (to_mathint(getStreamDeposit(streamId)) - sumWithdrawalsPerStream[streamId])
    filtered { f-> f.selector != createStream(address, uint256, address, uint256, uint256).selector }

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
// TODO: fails due to reentrancy
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

rule noStreamAfterCancel(uint256 streamId) {
    env e;

    require getStreamExists(streamId);
    cancelStream(e, streamId);
    assert !getStreamExists(streamId);
}

// balance is not 0. do an op. if balance is 0 then stream not exists.
rule zeroRemainingBalanceDeleted(method f, uint256 streamId) {
    env e;
    calldataarg args;

    uint256 balanceBefore = getStreamRemainingBalance(streamId);
    require balanceBefore > 0;

    f(e, args);

    uint256 balanceAfter = getStreamRemainingBalance(streamId);
    assert balanceAfter > 0;

}

// 9. if recipient can't withdraw balance then erc20 balanceof(this contract) is not sufficient
// if wihdraw failed and all params are good, then not enough tokens on the balance
// doesn't work
// rule failedWithdrawWhenInsolventOnly(uint256 streamId, uint256 amount){
//     env e;
//     calldataarg args;

//     require getStreamExists(streamId);
//     require e.msg.sender == getStreamRecipient(streamId) && e.msg.sender != 0;
//     uint256 balance = balanceOf(e, streamId, e.msg.sender);
//     require balance < getStreamDeposit(streamId);
//     require amount <= balance && amount > 0;

//     uint256 tokenBalance = _asset.balanceOf(currentContract);
//     require _status() != 2;
//     withdrawFromStream@withrevert(e, streamId, e.msg.sender);
//     assert lastReverted => tokenBalance < amount;
// }

// doesn't work - reverts in token safeTransfer
// try with same stream and same token
// TODO fails
rule withdrawAvailable(uint256 stream1, uint256 stream2, uint256 amount1, uint256 amount2 ) {
    env e1;
    env e2;
    storage init = lastStorage;

    withdrawFromStream(e1, stream1, amount1);

    require getStreamExists(stream2);
    require e2.msg.sender == getStreamRecipient(stream2) && e2.msg.sender != 0;
    uint256 balance = balanceOf(e2, stream2, e2.msg.sender);
    require balance < getStreamDeposit(stream2);
    require amount2 <= balance && amount2 > 0;

    uint256 tokenBalance = _asset.balanceOf(currentContract);
    withdrawFromStream@withrevert(e2, stream2, amount2) at init;

    assert lastReverted => tokenBalance < amount2;

}


// 1.5 after any action treasure balanceOf(token) doesn't decrease. 
//  only on withdraw and cancel it can decrease appropriately

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


