// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {BaseTest} from "./base/BaseTest.sol";
import {PayloadAaveBGD} from "../PayloadAaveBGD.sol";
import {AaveGovHelpers, IAaveGov} from "./utils/AaveGovHelpers.sol";
import {ApproximateMath} from "./utils/ApproximateMath.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {console} from "./utils/console.sol";

contract ValidationProposal is BaseTest {
    address internal constant AAVE_WHALE =
        0x25F2226B597E8F9514B3F68F00f494cF4f286491;

    error InvalidTransferOfUpfront(
        IERC20 asset,
        uint256 expectedBalance,
        uint256 currentBalance
    );

    function setUp() public {}

    function testProposalPrePayload() public {
        address payload = address(new PayloadAaveBGD());

        _testProposal(payload);
    }

    function _testProposal(address payload) internal {
        address[] memory targets = new address[](1);
        targets[0] = payload;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "execute()";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        bool[] memory withDelegatecalls = new bool[](1);
        withDelegatecalls[0] = true;

        uint256 proposalId = AaveGovHelpers._createProposal(
            vm,
            AAVE_WHALE,
            IAaveGov.SPropCreateParams({
                executor: AaveGovHelpers.SHORT_EXECUTOR,
                targets: targets,
                values: values,
                signatures: signatures,
                calldatas: calldatas,
                withDelegatecalls: withDelegatecalls,
                ipfsHash: bytes32(0)
            })
        );

        AaveGovHelpers._passVote(vm, AAVE_WHALE, proposalId);

        if (
            !ApproximateMath._almostEqual(
                IERC20(PayloadAaveBGD(payload).AUSDC()).balanceOf(
                    PayloadAaveBGD(payload).BGD_RECIPIENT()
                ),
                PayloadAaveBGD(payload).AUSDC_UPFRONT_AMOUNT()
            )
        ) {
            revert InvalidTransferOfUpfront(
                PayloadAaveBGD(payload).AUSDC(),
                PayloadAaveBGD(payload).AUSDC_UPFRONT_AMOUNT(),
                IERC20(PayloadAaveBGD(payload).AUSDC()).balanceOf(
                    PayloadAaveBGD(payload).BGD_RECIPIENT()
                )
            );
        }

        if (
            !ApproximateMath._almostEqual(
                IERC20(PayloadAaveBGD(payload).ADAI()).balanceOf(
                    PayloadAaveBGD(payload).BGD_RECIPIENT()
                ),
                PayloadAaveBGD(payload).ADAI_UPFRONT_AMOUNT()
            )
        ) {
            revert InvalidTransferOfUpfront(
                PayloadAaveBGD(payload).ADAI(),
                PayloadAaveBGD(payload).ADAI_UPFRONT_AMOUNT(),
                IERC20(PayloadAaveBGD(payload).ADAI()).balanceOf(
                    PayloadAaveBGD(payload).BGD_RECIPIENT()
                )
            );
        }

        if (
            !ApproximateMath._almostEqual(
                IERC20(PayloadAaveBGD(payload).AUSDT()).balanceOf(
                    PayloadAaveBGD(payload).BGD_RECIPIENT()
                ),
                PayloadAaveBGD(payload).AUSDT_UPFRONT_AMOUNT()
            )
        ) {
            revert InvalidTransferOfUpfront(
                PayloadAaveBGD(payload).AUSDT(),
                PayloadAaveBGD(payload).AUSDT_UPFRONT_AMOUNT(),
                IERC20(PayloadAaveBGD(payload).AUSDT()).balanceOf(
                    PayloadAaveBGD(payload).BGD_RECIPIENT()
                )
            );
        }

        if (
            !ApproximateMath._almostEqual(
                IERC20(PayloadAaveBGD(payload).AAVE()).balanceOf(
                    PayloadAaveBGD(payload).BGD_RECIPIENT()
                ),
                PayloadAaveBGD(payload).AAVE_UPFRONT_AMOUNT()
            )
        ) {
            revert InvalidTransferOfUpfront(
                PayloadAaveBGD(payload).AAVE(),
                PayloadAaveBGD(payload).AAVE_UPFRONT_AMOUNT(),
                IERC20(PayloadAaveBGD(payload).AAVE()).balanceOf(
                    PayloadAaveBGD(payload).BGD_RECIPIENT()
                )
            );
        }
    }
}
