# Aave ecosystem reserve V2

This repository contains an implementation to update the Aave ecosystem reserve proxy located [here](https://etherscan.io/address/0x464c71f6c2f760dda6093dcb91c24c39e5d6e18c), and the reserve of AAVE located [here](https://etherscan.io/address/0x25f2226b597e8f9514b3f68f00f494cf4f286491) in order to allow native streaming of funds from them.
The rationale of this change is that, as more and more external parties like BGD engage with the Aave DAO, and the compensation is usually via stream of funds, it is not optimal to send the whole capital of the stream upfront to a system like the current Sablier v1 as:

- The current funds would be sent there as growing-balance aTokens (unless wrapped), which Sablier doesn't support.
- It is not optimal to lock funds somewhere else, when knowing that in long streams, the majority will still be available for the ecosystem reserve to dispose if afterwards they get refilled.

So in order to enable this, the strategy has been:

- Create a new contract inheriting from the current implementation present under the proxy of the ecosystem reserve. This assures that all storage layout remains fully compatible, with only new layout "on top".
- Port the majority of the logic of Sablier v1 to our new contract, with the following changes:
  - The concept of `sender` gets reduced to the `_fundsAdmin`, which will be the current controller of reserve contract. This means that nobody apart from the `_fundsAdmin` is able to create/cancel streams. On withdrawal, the same but obviously allowing the recipient of the stream to withdraw too.
  - On Sablier v1, on creation the whole `deposit` funds are transferred from the sender to the contract itself. In our case, it is assumed that the ecosystem reserve always has funds, so no `transferFrom()` required.
  - Parallel to creation, on cancellation of a stream, the funds that should be returned to the `sender` of the stream are not sent anywhere, they just remain in the ecosystem reserve.
  - SafeMath/CarefulMath are not needed, as the code has been updated to Solidity 0.8.11, already including native safe math.

Here it is possible to see a full diff of the changes done [https://www.diffchecker.com/JGvs8U3u](https://www.diffchecker.com/JGvs8U3u).
<br>
<br>

## Aave <> BGD governance payload

As the previously described update of the ecosystem reserve is a pre-requirement for the [AAVE <> BGD Labs](https://governance.aave.com/t/aave-bored-ghosts-developing-bgd/7527) proposal, this repository includes also the proposal's payload to be submitted.
It can be found on [PayloadAaveBGD](./src/PayloadAaveBGD.sol) and does the following:
1. Deploys a new controller of the ecosystem reserve, to be used by the short executor to control both the protocol's ecosystem reserve and the AAVE reserve. Its `owner` will be the Aave governance short executor.
2. Deploys the implementation of the new AaveEcosystemReserveV2, with streaming capabilities. To be used also as implementation for both the protocol's ecosystem reserve and the AAVE reserve, under their own transparent proxy contracts.
3. Upgrades both ecosystem reserves with the implementation deployed on 2) and setting as `_fundsAdmin` the controller contract deployed on 1).
4. Initializes the implementation of the ecosystem reserve, for security hygiene.
5. Transfers the upfront amounts defined in the proposal to a BGD-controlled address: aUSDC, aDAI, aUSDT and aDAI.
6. Creates the 15-months streams of aUSDC and AAVE to the BGD-controlled address.

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
