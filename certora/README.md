# Formal verification of AaveStreamingTreasuryV1

## Latest run

[https://vaas-stg.certora.com/output/67509/d3a0f7e6aeb0b787c9aa/index.html?anonymousKey=408e7660802fae01ff8649a4855490adfbbf4824](https://vaas-stg.certora.com/output/67509/d3a0f7e6aeb0b787c9aa/index.html?anonymousKey=408e7660802fae01ff8649a4855490adfbbf4824)

## Harness

Verification runs on AaveStreamingTreasuryHarness.sol - a slight modification of the original code.

List of changes:
1. Removed reentrancy guard on withdrawFromStream()
2. Removed dependency on SafeERC20 library, working with basic IERC20 and DummyERC20Impl.sol
3. Added `getStreamExists` public getter
4. Changed  `_nextStreamId` visibility to public

## General Properties

1. *invariant* `withdrawalsSolvent`

- (sum of all withdrawals from a stream) <= deposit. So that treasure cannot lose money.

2. *rule* `treasuryBalanceCorrectness`

- treasury's balanceOf(token) can decrease appropriately only on withdraw and cancel.

3. *invariant* `ratePerSecond_GE_1`

- For all streams, stream.ratePerSecond >= 1 (valid state).

4. *rule* `integrityOfWithdraw`

- can't withdraw more than current balanceOf() and original deposit.

5. *rule* `fullWithdrawPossible`

- withdraw is possible: if user can withdraw x, they can withdraw their whole balanceOf.
   assuming contract has all the tokens (max uint)

6. *invariant*  `remainingBalance_LE_deposit`

- For all streams, remaining balance <= deposit 

7. *invariant* `balanceOf_LE_deposit`

- For all streams, balance of recipient <= deposit

8. *invariant* `cantWithdrawTooEarly`

- For all streams, recipient can't withdraw anything before start time is reached.

9. *rule* `streamRemainingBalanceMonotonicity`

- stream.remainingBalance can only go down 

10. *invariant* `streamHasSenderAndRecipient`

- isEntity => recipient != 0 && sender != 0


## Specific function properties

1. *rule* `deltaOfCorrectness`

- deltaOf(): 
    block.timeStamp <= stream.startTime => delta = 0
    block.timeStamp <= stream.stopTime => delta = stream.stopTime - stream.startTime
    block.timeStamp > stream.stopTime => delta = block.stopTime - block.startTime

    deltaOf() reverts if stream doesn't exist (isEntity == false)

2. *rule* `createStreamCorrectness`

- createStream():
    - recipient is not 0, msg.sender or the contract.
    - startTime >= block.timestamp
    - duration > 0 (equivalent to stopTime - startTime > 0)
    - deposit >= duration
    - ratePerSecond = deposit / duration
    - deposit is a multiple of duration (no remainders)

3. *rule* `noStreamAfterCancel`

- cancelStream():
    - stream deleted after cancel

4. *rule* `zeroRemainingBalanceDeleted`

- stream with remainingBalance of 0 is deleted. (withdraw)

5. *rule* `ratePerSecondSetOnlyOnce`

- stream ratePerSecond is only set once in createStream()

6. *rule* `withdrawAvailable`

- If withdraw is available for one stream, it's also available for another stream

7. *rule* `nextStreamIdCorrectness`

- nextStreamId only goes up 

8. *rule* `onlyFundAdminCanCreate`

- only fund admin can call createStream()