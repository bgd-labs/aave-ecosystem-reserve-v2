# Formal verification of AaveStreamingTreasuryV1

## Latest run

[https://vaas-stg.certora.com/output/67509/d3a0f7e6aeb0b787c9aa/index.html?anonymousKey=408e7660802fae01ff8649a4855490adfbbf4824](https://vaas-stg.certora.com/output/67509/d3a0f7e6aeb0b787c9aa/index.html?anonymousKey=408e7660802fae01ff8649a4855490adfbbf4824)

## Harness

Verification runs on AaveStreamingTreasuryHarness.sol - a slight modification of the original code.

List of changes:
1. Removed reentrancy guard on withdrawFromStream()
2. Removed dependency on SafeERC20 library, working with basic IERC20 and DummyERC20Impl.sol
3. Added `getStreamExists` public getter

## Major properties

1. (sum of all withdrawals from a stream) <= deposit. So that treasure cannot lose money.
invariant `withdrawalsSolvent`

2. treasury's balanceOf(token) can decrease appropriately only on withdraw and cancel.
rule `treasuryBalanceCorrectness`

3. For all streams, stream.ratePerSecond >= 1 (valid state).
invariant `ratePerSecond_GE_1` [v]

4. can't withdraw more than current balanceOf() and original deposit.
rule `integrityOfWithdraw` [v]

5. withdraw is possible: if user can withdraw x, they can withdraw their whole balanceOf.
   assuming contract has all the tokens (max uint)
rule `fullWithdrawPossible` [v]

6. For all streams, remaining balance <= deposit 
invariant  `remainingBalance_LE_deposit` [v]

7. For all streams, balance of recipient <= deposit
invariant `balanceOf_LE_deposit` [v]

8. For all streams, recipient can't withdraw anything before start time is reached.
invariant `cantWithdrawTooEarly` [v]

9. stream.remainingBalance can only go down 
rule `streamRemainingBalanceMonotonicity` [v]


## Other properties

1. deltaOf(): 
    block.timeStamp <= stream.startTime => delta = 0
    block.timeStamp <= stream.stopTime => delta = stream.stopTime - stream.startTime
    block.timeStamp > stream.stopTime => delta = block.stopTime - block.startTime

    deltaOf() reverts if stream doesn't exist (isEntity == false)
`deltaOfCorrectness` [v]

2. createStream():
    - recipient is not 0, msg.sender or the contract.
    - startTime >= block.timestamp
    - duration > 0 (equivalent to stopTime - startTime > 0)
    - deposit >= duration
    - ratePerSecond = deposit / duration
    - deposit is a multiple of duration (no remainders)

`createStreamCorrectness` [v]

3. cancelStream():
    - stream deleted after cancel
`noStreamAfterCancel` [v]

5. stream with remainingBalance of 0 is deleted. (withdraw)
`zeroRemainingBalanceDeleted` [v]

6. isEntity => recipient != 0 && sender != 0
`streamHasSenderAndRecipient` [v]

7. stream ratePerSecond is only set once in createStream()
`ratePerSecondSetOnlyOnce`

9. if recipient can't withdraw balance then erc20 balanceof(this contract) is not sufficient
`failedWithdrawWhenInsolventOnly` [x] - fails with reentrancy counterexample

10. nextStreamId only goes up 
 `nextStreamIdCorrectness` [v]
