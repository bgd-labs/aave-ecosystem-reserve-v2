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

- balanceOf(stream,  address) >= 0
- balanceOf(recipient) when block timestamp > stream.stopTime is the whole deposit


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

#### cancelStream()

- line 304 `uint256 senderBalance = balanceOf(streamId, stream.sender);` is redundant (unused)
- recipient gets their current balance back
- recipient can't get more than their current balance.

### General properties

- for any stream, remaining balance <= deposit
- for any stream, recipient can withdraw everything after stopTime is reached
- stream with id below 100000 can't exist.
- stream with remainingBalance of 0 is deleted.
- isEntity => recipient != 0 && sender != 0
- can't withdraw more than delta * ratePerSecond
- sum of all withdrawals <= deposit



