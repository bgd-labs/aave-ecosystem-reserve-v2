# Formal verification of AaveStreamingTreasuryV1

## Latest run

[https://vaas-stg.certora.com/output/67509/d3a0f7e6aeb0b787c9aa/index.html?anonymousKey=408e7660802fae01ff8649a4855490adfbbf4824](https://vaas-stg.certora.com/output/67509/d3a0f7e6aeb0b787c9aa/index.html?anonymousKey=408e7660802fae01ff8649a4855490adfbbf4824)

## Harness

Verification runs on AaveStreamingTreasuryHarness.sol - a slight modification of the original code.

List of changes:
1. Removed reentrancy guard on withdrawFromStream()
2. Removed dependency on SafeERC20 library, working with basic IERC20 and DummyERC20Impl.sol
3. Added `getStreamExists` public getter

## General Properties

1. (sum of all withdrawals from a stream) <= deposit. So that treasure cannot lose money.
*invariant* `withdrawalsSolvent`

2. treasury's balanceOf(token) can decrease appropriately only on withdraw and cancel.
*rule* `treasuryBalanceCorrectness`

3. For all streams, stream.ratePerSecond >= 1 (valid state).
*invariant* `ratePerSecond_GE_1`

4. can't withdraw more than current balanceOf() and original deposit.
*rule* `integrityOfWithdraw`

5. withdraw is possible: if user can withdraw x, they can withdraw their whole balanceOf.
   assuming contract has all the tokens (max uint)
*rule* `fullWithdrawPossible`

6. For all streams, remaining balance <= deposit 
*invariant*  `remainingBalance_LE_deposit`

7. For all streams, balance of recipient <= deposit
*invariant* `balanceOf_LE_deposit`

8. For all streams, recipient can't withdraw anything before start time is reached.
*invariant* `cantWithdrawTooEarly`

9. stream.remainingBalance can only go down 
*rule* `streamRemainingBalanceMonotonicity`

10. isEntity => recipient != 0 && sender != 0
*invariant* `streamHasSenderAndRecipient`


## Specific function properties

1. deltaOf(): 
    block.timeStamp <= stream.startTime => delta = 0
    block.timeStamp <= stream.stopTime => delta = stream.stopTime - stream.startTime
    block.timeStamp > stream.stopTime => delta = block.stopTime - block.startTime

    deltaOf() reverts if stream doesn't exist (isEntity == false)
*rule* `deltaOfCorrectness`

2. createStream():
    - recipient is not 0, msg.sender or the contract.
    - startTime >= block.timestamp
    - duration > 0 (equivalent to stopTime - startTime > 0)
    - deposit >= duration
    - ratePerSecond = deposit / duration
    - deposit is a multiple of duration (no remainders)

*rule* `createStreamCorrectness`

3. cancelStream():
    - stream deleted after cancel
*rule* `noStreamAfterCancel`

4. stream with remainingBalance of 0 is deleted. (withdraw)
*rule* `zeroRemainingBalanceDeleted`

5. stream ratePerSecond is only set once in createStream()
*rule* `ratePerSecondSetOnlyOnce`

6. If withdraw is available for one stream, it's also available for another stream
*rule* `withdrawAvailable`

7. nextStreamId only goes up 
 *rule* `nextStreamIdCorrectness` [v]
