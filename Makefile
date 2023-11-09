# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge build
test   :; forge test -vvv --rpc-url=${ETH_RPC_URL}
trace   :; forge test -vvvv --rpc-url=${ETH_RPC_URL}
clean  :; forge clean
snapshot :; forge snapshot

git-diff :;
	@mkdir -p diffs
	@printf '%s\n%s\n%s\n' "\`\`\`diff" "$$(git diff --no-index --diff-algorithm=patience --ignore-space-at-eol ${before} ${after})" "\`\`\`" > diffs/${out}.md


flatten-contracts :;
	forge flatten ./src/AaveEcosystemReserveV2.sol > flatten/AaveEcosystemReserveV2.sol

download-deployed-contracts :;
	cast etherscan-source --chain 1 -d etherscan/deployed/ecosystemReserve 0x10c74b37Ad4541E394c607d78062e6d22D9ad632 # ecosystem reserve implementation


diff-deployed-contracts :;
	make git-diff before=etherscan/deployed/ecosystemReserve/AaveEcosystemReserveV2/src/contracts/AaveEcosystemReserveV2.sol after=flatten/AaveEcosystemReserveV2.sol out=AaveEcosystemReserveV2.sol