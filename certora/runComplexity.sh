certoraRun  src/AaveStreamingTreasuryV1.sol:AaveStreamingTreasuryV1 certora/DummyERC20Impl.sol \
    --verify AaveStreamingTreasuryV1:certora/complexity.spec \
    --solc solc8.11 \
    --staging \
    --send_only \
    --optimistic_loop \
    --settings -enableEqualitySaturation=false,-solver=z3,-smt_usePz3=true,-smt_z3PreprocessorTimeout=2 \
    --solc_args '["--experimental-via-ir"]' \
    --msg "CometHarness:comet.spec $RULE"