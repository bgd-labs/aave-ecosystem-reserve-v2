// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {BaseTest} from "./base/BaseTest.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IStreamable} from "../interfaces/IStreamable.sol";
import {IOwnable} from "../interfaces/IOwnable.sol";
import {IAdminControlledEcosystemReserve} from "../interfaces/IAdminControlledEcosystemReserve.sol";
import {IAaveEcosystemReserveController} from "../interfaces/IAaveEcosystemReserveController.sol";
import {IInitializableAdminUpgradeabilityProxy} from "../interfaces/IInitializableAdminUpgradeabilityProxy.sol";
import {PayloadAaveBGD} from "../PayloadAaveBGD.sol";
import {AaveGovHelpers, IAaveGov} from "./utils/AaveGovHelpers.sol";
import {ApproximateMath} from "./utils/ApproximateMath.sol";
import {console} from "./utils/console.sol";

contract ValidationProposal is BaseTest {
    address internal constant AAVE_WHALE =
        0x25F2226B597E8F9514B3F68F00f494cF4f286491;

    error InvalidTransferOfUpfront(
        IERC20 asset,
        uint256 expectedBalance,
        uint256 currentBalance
    );

    error InvalidBalanceAfterWithdraw(
        IERC20 asset,
        uint256 expectedBalance,
        uint256 currentBalance
    );

    error WrongOwnerOfController(address expect, address current);

    error InconsistentFundsAdminOfReserves(
        address controllerOfProtocolReserve,
        address controllerOfAaveReserve
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

        _validatePostProposalUpfronts(proposalId);
        _validatePostProposalStreams(proposalId);
        _validatePostProposalACL(proposalId);
    }

    function _validatePostProposalUpfronts(uint256 proposalId) internal {
        IAaveGov.ProposalWithoutVotes memory proposalData = AaveGovHelpers
            ._getProposalById(proposalId);
        // Generally, there is no reason to have more than 1 payload if using the DELEGATECALL pattern
        address payload = proposalData.targets[0];

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

    function _validatePostProposalStreams(uint256 proposalId) internal {
        IAaveGov.ProposalWithoutVotes memory proposalData = AaveGovHelpers
            ._getProposalById(proposalId);
        address payload = proposalData.targets[0];

        IStreamable collectorProxy = IStreamable(
            address(PayloadAaveBGD(payload).COLLECTOR_V2_PROXY())
        );
        IStreamable aaveCollectorProxy = IStreamable(
            address(PayloadAaveBGD(payload).AAVE_TOKEN_COLLECTOR_PROXY())
        );
        (
            ,
            address recipient,
            ,
            ,
            uint256 startTime,
            ,
            ,
            uint256 ratePerSecond
        ) = collectorProxy.getStream(100000);

        (
            ,
            ,
            ,
            ,
            uint256 startTimeAave,
            ,
            ,
            uint256 ratePerSecondAave
        ) = aaveCollectorProxy.getStream(100000);

        vm.warp(startTime + 1 days);
        address bgdRecipient = PayloadAaveBGD(payload).BGD_RECIPIENT();
        IERC20 aUsdc = PayloadAaveBGD(payload).AUSDC();
        IERC20 aave = PayloadAaveBGD(payload).AAVE();

        uint256 recipientAUsdcBalanceBefore = aUsdc.balanceOf(bgdRecipient);
        uint256 recipientAaveBalanceBefore = aave.balanceOf(bgdRecipient);

        vm.startPrank(bgdRecipient);

        collectorProxy.withdrawFromStream(
            100000,
            collectorProxy.balanceOf(100000, bgdRecipient)
        );

        aaveCollectorProxy.withdrawFromStream(
            100000,
            aaveCollectorProxy.balanceOf(100000, bgdRecipient)
        );

        if (
            aUsdc.balanceOf(bgdRecipient) <
            (recipientAUsdcBalanceBefore + (ratePerSecond * 1 days))
        ) {
            revert InvalidBalanceAfterWithdraw(
                aUsdc,
                recipientAUsdcBalanceBefore + (ratePerSecond * 1 days),
                aUsdc.balanceOf(bgdRecipient)
            );
        }

        if (
            aave.balanceOf(bgdRecipient) <
            (recipientAaveBalanceBefore + (ratePerSecondAave * 1 days))
        ) {
            revert InvalidBalanceAfterWithdraw(
                aave,
                recipientAaveBalanceBefore + (ratePerSecondAave * 1 days),
                aave.balanceOf(bgdRecipient)
            );
        }

        vm.stopPrank();
    }

    function _validatePostProposalACL(uint256 proposalId) internal {
        IAaveGov.ProposalWithoutVotes memory proposalData = AaveGovHelpers
            ._getProposalById(proposalId);
        PayloadAaveBGD payload = PayloadAaveBGD(proposalData.targets[0]);

        address protocolReserve = address(
            PayloadAaveBGD(payload).COLLECTOR_V2_PROXY()
        );
        address aaveReserve = address(
            PayloadAaveBGD(payload).AAVE_TOKEN_COLLECTOR_PROXY()
        );

        // The controller of the reserve for both protocol's and AAVE treasuries is owned by the short executor
        address controllerOfProtocolReserve = IAdminControlledEcosystemReserve(
            protocolReserve
        ).getFundsAdmin();

        address controllerOfAaveReserve = IAdminControlledEcosystemReserve(
            aaveReserve
        ).getFundsAdmin();

        address shortExecutor = payload.GOV_SHORT_EXECUTOR();

        if (controllerOfProtocolReserve != controllerOfAaveReserve) {
            revert InconsistentFundsAdminOfReserves(
                controllerOfProtocolReserve,
                controllerOfAaveReserve
            );
        }

        if (IOwnable(controllerOfProtocolReserve).owner() != shortExecutor) {
            revert WrongOwnerOfController(
                shortExecutor,
                IOwnable(controllerOfProtocolReserve).owner()
            );
        }

        vm.startPrank(address(1));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IAaveEcosystemReserveController(controllerOfProtocolReserve).approve(
            address(0),
            IERC20(address(0)),
            address(0),
            0
        );
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IAaveEcosystemReserveController(controllerOfProtocolReserve).transfer(
            address(0),
            IERC20(address(0)),
            address(0),
            0
        );

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IAaveEcosystemReserveController(controllerOfProtocolReserve)
            .createStream(address(0), address(0), 0, address(0), 0, 0);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IAaveEcosystemReserveController(controllerOfProtocolReserve)
            .cancelStream(address(0), 0);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IAaveEcosystemReserveController(controllerOfProtocolReserve)
            .withdrawFromStream(address(0), 0, 0);

        vm.stopPrank();

        // Test of ownership of treasuries' by short executor. Only proxy's owner can call admin()
        vm.startPrank(shortExecutor);
        IInitializableAdminUpgradeabilityProxy(protocolReserve).admin();
        IInitializableAdminUpgradeabilityProxy(aaveReserve).admin();
        vm.stopPrank();

        // ACL of the protocols's ecosystem reserve functions. Only by controller of reserve
        vm.startPrank(address(1));
        vm.expectRevert(bytes("ONLY_BY_FUNDS_ADMIN"));
        IAdminControlledEcosystemReserve(protocolReserve).approve(
            IERC20(address(0)),
            address(0),
            0
        );
        vm.expectRevert(bytes("ONLY_BY_FUNDS_ADMIN"));
        IAdminControlledEcosystemReserve(protocolReserve).transfer(
            IERC20(address(0)),
            address(0),
            0
        );

        vm.expectRevert(bytes("ONLY_BY_FUNDS_ADMIN"));
        IStreamable(protocolReserve).createStream(
            address(0),
            0,
            address(0),
            0,
            0
        );

        vm.expectRevert(
            bytes(
                "caller is not the funds admin or the recipient of the stream"
            )
        );
        IStreamable(protocolReserve).cancelStream(100000);

        vm.expectRevert(
            bytes(
                "caller is not the funds admin or the recipient of the stream"
            )
        );
        IStreamable(protocolReserve).withdrawFromStream(100000, 0);

        // ACL of the AAVE's ecosystem reserve functions. Only by controller of reserve

        vm.expectRevert(bytes("ONLY_BY_FUNDS_ADMIN"));
        IAdminControlledEcosystemReserve(aaveReserve).approve(
            IERC20(address(0)),
            address(0),
            0
        );
        vm.expectRevert(bytes("ONLY_BY_FUNDS_ADMIN"));
        IAdminControlledEcosystemReserve(aaveReserve).transfer(
            IERC20(address(0)),
            address(0),
            0
        );

        vm.expectRevert(bytes("ONLY_BY_FUNDS_ADMIN"));
        IStreamable(aaveReserve).createStream(address(0), 0, address(0), 0, 0);

        vm.expectRevert(
            bytes(
                "caller is not the funds admin or the recipient of the stream"
            )
        );
        IStreamable(aaveReserve).cancelStream(100000);

        vm.expectRevert(
            bytes(
                "caller is not the funds admin or the recipient of the stream"
            )
        );
        IStreamable(aaveReserve).withdrawFromStream(100000, 0);

        vm.stopPrank();
    }
}
