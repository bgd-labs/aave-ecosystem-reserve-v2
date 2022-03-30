## AaveStreamingTreasury properties

work in progress

### Timestamps

- deltaOf() returns a number >= 0

- deltaOf(): 
    block.timeStamp <= stream.startTime => delta = 0
    block.timeStamp <= stream.stopTime => delta = stream.stopTime - stream.startTime
    block.timeStamp > stream.stopTime => delta = block.stopTime - block.startTime

- deltaOf() reverts if stream doesn't exist (isEntity == false)

### Balances

- balanceOf(stream,  address) >= 0. (irrelevant) ??
- balanceOf(recipient) when block timestamp > stream.stopTime is the whole deposit. doesn't work if withdrawal happened. ??
- total withdraw: sum of all withdrawals <= deposit

### rate per second

- rps >= 1 (valid state)



#### createStream()

- recipient is not 0, msg.sender or the contract.
- startTime >= block.timestamp
- duration > 0 (equivalent to stopTime - startTime > 0)
- deposit >= duration
- ratePerSecond = deposit / duration
- deposit is a multiple of duration (no remainders)



#### withdrawStream()

- can't withdraw more than current balanceOf(stream, recipient)
- can't withdraw more than the original deposit

- withdraw is possible: if user can withdraw x, they can withdraw their whole balanceOf.
  assuming aave treasury has all the tokens (max uint)

#### cancelStream()

- line 304 `uint256 senderBalance = balanceOf(streamId, stream.sender);` is redundant (unused)
- recipient gets their current balance back
- recipient can't get more than their current balance.
- if the block is after stopTime, all the remaining balance goes to recipient.

### stream properties
- solvency:
- for any stream, remaining balance <= deposit
- for any stream, recipient can withdraw everything after stopTime is reached
- stream with id below 100000 can't exist.
- stream with remainingBalance of 0 is deleted.
- isEntity => recipient != 0 && sender != 0
- can't withdraw more than delta * ratePerSecond
- sum of all withdrawals <= deposit

- for any withdrawal, remaining balance gets updated.

# general properties

- stream remaining balance can only go down [v]
- stream ratePerSecond is only set once in createStream()
- deposit >= remainingBalance. deposit != 0. deposit % duration == 0.
- if recipient can't withdraw balance then erc20 balanceof(this contract) is not sufficient
- no stream with `nextStreamId` stream id exists.


## general

- most important: nobody can withdraw more money than they're supposed to get (stream.deposit)