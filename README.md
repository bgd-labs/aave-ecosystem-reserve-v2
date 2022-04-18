# Aave streaming treasury

This repository contains an implementation to update the Aave treasury proxy located [here](https://etherscan.io/address/0x464c71f6c2f760dda6093dcb91c24c39e5d6e18c), in order to allow native streaming of funds from it.
The rationale of this change is that, as more and more external parties like BGD engage with the Aave DAO, and the compensation is usually via stream of funds, it is not optimal to send the whole capital of the stream upfront to a system like the current Sablier v1 as:

- The current funds would be sent there as growing-balance aTokens (unless wrapped), which Sablier doesn't support.
- It is not optimal to lock funds somewhere else, even knowing that in long streams, the majority will still be available for the treasury to dispose if afterwards they get refilled.

So in order to enable this, the strategy has been:

- Create a new contract inheriting from the current implementation present under the proxy of the treasury. This assures that all storage layout remains fully compatible, with only new layout "on top".
- Port the majority of the logic of Sablier v1 to our new contract, with the following changes:
  - The concept of `sender` gets reduced to the `_fundsAdmin`, which will be the current controller of reserve contract. This means that nobody apart from the `_fundsAdmin` is able to create/cancel streams. On withdrawal, the same but obviously allowing the recipient of the stream to withdraw too.
  - On Sablier v1, on creation the whole `deposit` funds are transferred from the sender to the contract itself. In our case, it is assumed that the treasury always has funds, so no `transferFrom()` required.
  - Parallel to creation, on cancellation of a stream, the funds that should be returned to the `sender` of the stream are not sent anywhere, they just remain in the treasury.
  - SafeMath/CarefulMath are not needed, as the code has been updated to Solidity 0.8.11, already including native safe math.

<br>
<br>

## Security

- Full test coverage via units tests in the Forge environment.
- Security review from Aave community members.
- Minimal changes on Sablier's v1 logic, which is [audited](https://medium.com/sablier/sablier-v1-is-live-5a5350db16ae) and battle tested codebase (running in production with meaningful funds for a long time).
- Set of properties (formal verification) by Certora.

<br>
<br>

## Running the repository

### Dependencies

```
make update
```

### Compilation

```
make build
```

### Testing

```
make test
```

or for more extensive trace

```
make trace
```

<br>
<br>

## Acknowledgments

Big credit for the amazing job done by [Sablier](https://sablier.finance/), used as base of this implementation.
And as usual, thanks to the Aave community members who participated reviewing and giving feedback.

<br>
<br>

## License

This repository is under [GPL-3.0 License](./LICENSE).
Copyright (C) 2022 BGD Labs
