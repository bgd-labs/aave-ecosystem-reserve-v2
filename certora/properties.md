
## Major properties

1. (sum of all withdrawals from a stream) <= deposit. So that treasure cannot lose money.
invariant `withdrawalsSolvent`

10. treasury's balanceOf(token) can decrease appropriately only on withdraw and cancel.
rule `treasuryBalanceCorrectness`

2. For all streams, stream.ratePerSecond >= 1 (valid state).
invariant `ratePerSecond_GE_1` [v]

3. can't withdraw more than current balanceOf() and original deposit.
rule `integrityOfWithdraw` [v]

4. withdraw is possible: if user can withdraw x, they can withdraw their whole balanceOf.
   assuming contract has all the tokens (max uint)
rule `fullWithdrawPossible` [v]

5. on cancelStream, recipient always get their whole balanceOf() back.
? how to test token balance when token contract is not linked ?

6. For all streams, remaining balance <= deposit 
invariant  `remainingBalance_LE_deposit` [v]

7. For all streams, balance of recipient <= deposit
invariant `balanceOf_LE_deposit` [v]

7. For all streams, recipient can't withdraw anything before start time is reached.
invariant `cantWithdrawTooEarly` [v]

8. stream.remainingBalance can only go down 
rule `streamRemainingBalanceMonotonicity` [v]

9. additivity of withdraw ?


## Minor

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

11. nextStreamId only goes up 
 `nextStreamIdCorrectness` [v]

## Doubt

- no stream with `nextStreamId` stream id exists.
Not so important.