if [[ "$1" ]]
then
    RULE="--rule $1"
fi

certoraRun  certora/AaveEcosystemReserveV2Harness.sol:AaveEcosystemReserveV2 certora/DummyERC20Impl.sol \
    --verify AaveEcosystemReserveV2:certora/main.spec $RULE \
    --solc solc8.11 \
    --staging \
    --optimistic_loop \
    --settings -enableEqualitySaturation=false,-solver=z3,-smt_usePz3=true,-smt_z3PreprocessorTimeout=2 \
    --solc_args '["--experimental-via-ir"]' \
    --msg "CometHarness:comet.spec $RULE"