pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {DeployLancaBridgeHarnessScript} from "../scripts/DeployLancaBridgeHarness.s.sol";
import {LancaBridgeHarness} from "../harnesses/LancaBridgeHarness.sol";
import {console} from "forge-std/src/console.sol";
import {ILancaBridge} from "contracts/bridge/interfaces/ILancaBridge.sol";
import {ILancaBridgeStorage} from "contracts/bridge/interfaces/ILancaBridgeStorage.sol";
import {LancaBridgeTestBase} from "./LancaBridgeBase.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LancaBridgeClientMock} from "../mocks/LancaBridgeClientMock.sol";
import {IConceroClient} from "concero/contracts/ConceroClient/interfaces/IConceroClient.sol";

contract LancaBridgeTest is LancaBridgeTestBase {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_bridgeAddPendingSettlement() public {
        address sender = makeAddr("sender");
        address receiver = makeAddr("receiver");
        address bridgeToken = s_usdc;
        uint64 dstChainSelector = s_chainSelectorArb;
        uint256 amount = 100 * USDC_DECIMALS;
        bytes memory message = new bytes(0);
        uint32 dstChainGasLimit = 1_000_000;

        deal(bridgeToken, sender, amount);

        uint256 senderBalanceBefore = IERC20(bridgeToken).balanceOf(sender);

        vm.startPrank(sender);
        ILancaBridge.BridgeReq memory bridgeReq = ILancaBridge.BridgeReq({
            amount: amount,
            token: bridgeToken,
            feeToken: bridgeToken,
            receiver: receiver,
            fallbackReceiver: receiver,
            dstChainSelector: dstChainSelector,
            dstChainGasLimit: dstChainGasLimit,
            message: message
        });
        IERC20(bridgeToken).approve(address(s_lancaBridge), amount);
        uint256 bridgeFee = s_lancaBridge.getFee(
            bridgeReq.dstChainSelector,
            bridgeReq.amount,
            bridgeReq.feeToken,
            bridgeReq.dstChainGasLimit
        );

        (, , uint256 conceroMessageFee) = s_lancaBridge.getBridgeFeeBreakdown(
            bridgeReq.dstChainSelector,
            bridgeReq.amount,
            bridgeReq.feeToken,
            bridgeReq.dstChainGasLimit
        );

        bytes32 bridgeId = s_lancaBridge.bridge(bridgeReq);
        vm.stopPrank();

        uint256 senderBalanceAfter = IERC20(bridgeToken).balanceOf(sender);

        // @dev check that the sender's balance has decreased by the bridge amount
        assertEq(senderBalanceBefore - amount, senderBalanceAfter);

        // @dev check that the bridge has the pending settlement
        bytes32[] memory pendingSettlementIds = s_lancaBridge.getPendingSettlementIdsByDstChain(
            dstChainSelector
        );
        assertEq(pendingSettlementIds.length, 1);
        assertEq(bridgeId, pendingSettlementIds[0]);

        // @dev check pending settlement tx data
        ILancaBridgeStorage.PendingSettlementTx memory pendingSettlement = s_lancaBridge
            .getPendingSettlementTxById(bridgeId);

        assertEq(pendingSettlement.amount, amount - bridgeFee);
        assertEq(pendingSettlement.receiver, receiver);

        // @dev check total pending settlement amount by dst chain
        uint256 totalPendingSettlementAmount = s_lancaBridge.getPendingSettlementTxAmountByDstChain(
            dstChainSelector
        );
        assertEq(totalPendingSettlementAmount, amount - bridgeFee);

        // @dev check lancaBridge contract balance after performing the bridge
        assertEq(
            IERC20(bridgeToken).balanceOf(address(s_lancaBridge)),
            amount - (conceroMessageFee)
        );
    }

    function testFuzz_bridgeTriggerBatch(uint256 amount) public {
        vm.assume(
            amount > s_lancaBridge.exposed_getBatchedTxThreshold() &&
                amount < 1_000_000_000_000 * USDC_DECIMALS
        );

        address sender = makeAddr("sender");

        ILancaBridge.BridgeReq memory bridgeReq = _getBaseLancaBridgeReq();
        bridgeReq.amount = amount;
        deal(bridgeReq.token, sender, amount);

        uint256 senderBalanceBefore = IERC20(bridgeReq.token).balanceOf(sender);

        vm.startPrank(sender);

        IERC20(bridgeReq.token).approve(address(s_lancaBridge), amount);
        uint256 bridgeFee = s_lancaBridge.getFee(
            bridgeReq.dstChainSelector,
            bridgeReq.amount,
            bridgeReq.feeToken,
            bridgeReq.dstChainGasLimit
        );

        (uint256 ccipFee, uint256 lancaFee, ) = s_lancaBridge.getBridgeFeeBreakdown(
            bridgeReq.dstChainSelector,
            bridgeReq.amount,
            bridgeReq.feeToken,
            bridgeReq.dstChainGasLimit
        );

        bytes32 bridgeId = s_lancaBridge.bridge(bridgeReq);
        vm.stopPrank();

        uint256 senderBalanceAfter = IERC20(bridgeReq.token).balanceOf(sender);

        // @dev check that the sender's balance has decreased by the bridge amount
        assertEq(senderBalanceBefore - amount, senderBalanceAfter);

        // @dev check that the bridge has the pending settlement
        bytes32[] memory pendingSettlementIds = s_lancaBridge.getPendingSettlementIdsByDstChain(
            bridgeReq.dstChainSelector
        );

        assertEq(pendingSettlementIds.length, 0);

        // @dev check total pending settlement amount by dst chain
        uint256 totalPendingSettlementAmount = s_lancaBridge.getPendingSettlementTxAmountByDstChain(
            bridgeReq.dstChainSelector
        );
        assertEq(totalPendingSettlementAmount, 0);

        // @dev check lancaBridge contract balance after performing the bridge
        assertEq(IERC20(bridgeReq.token).balanceOf(address(s_lancaBridge)), ccipFee + lancaFee);
    }

    function test_conceroReceive() public {
        address lancaBridgeSender = makeAddr("lanca bridge sender");
        address lancaBridgeReceiver = address(new LancaBridgeClientMock(address(s_lancaBridge)));
        uint24 gasLimit = 1_000_000;
        uint256 amount = 530 * USDC_DECIMALS;
        bytes memory lancaBridgeMessageData = new bytes(300);

        bytes memory lancaBridgeMessage = abi.encode(
            ILancaBridge.LancaBridgeMessageVersion.V1,
            lancaBridgeSender,
            lancaBridgeReceiver,
            gasLimit,
            amount,
            lancaBridgeMessageData
        );

        IConceroClient.Message memory conceroMessage = IConceroClient.Message({
            id: keccak256("concero message id"),
            srcChainSelector: s_chainSelectorArb,
            sender: s_lancaBridgeArb,
            data: lancaBridgeMessage
        });

        vm.prank(s_lancaBridge.getConceroRouter());
        s_lancaBridge.conceroReceive(conceroMessage);
    }

    /* REVERTS */

    function testFuzz_bridgeInvalidBridgeToken_revert() public {
        address bridgeToken = makeAddr("wrong bridge token");

        vm.assume(bridgeToken != s_usdc);

        address sender = makeAddr("sender");

        ILancaBridge.BridgeReq memory bridgeReq = _getBaseLancaBridgeReq();
        bridgeReq.token = bridgeToken;

        vm.startPrank(sender);
        vm.expectRevert(ILancaBridge.InvalidBridgeToken.selector);
        s_lancaBridge.bridge(bridgeReq);
        vm.stopPrank();
    }

    function test_bridgeInvalidFeeToken_revert() public {
        address feeToken = makeAddr("wrong fee token");
        address sender = makeAddr("sender");

        ILancaBridge.BridgeReq memory bridgeReq = _getBaseLancaBridgeReq();
        bridgeReq.feeToken = feeToken;

        vm.startPrank(sender);
        vm.expectRevert(ILancaBridge.InvalidFeeToken.selector);
        s_lancaBridge.bridge(bridgeReq);
        vm.stopPrank();
    }

    function test_bridgeInvalidReceiver_revert() public {
        address sender = makeAddr("sender");
        address receiver = address(0);

        ILancaBridge.BridgeReq memory bridgeReq = _getBaseLancaBridgeReq();
        bridgeReq.receiver = receiver;

        vm.startPrank(sender);
        vm.expectRevert(ILancaBridge.InvalidReceiver.selector);
        s_lancaBridge.bridge(bridgeReq);
        vm.stopPrank();
    }

    function test_bridgeZeroDstChainGasLimit_revert() public {
        address sender = makeAddr("sender");
        uint32 dstChainGasLimit = s_lancaBridge.exposed_getMaxDstChainGasLimit() + 1;

        ILancaBridge.BridgeReq memory bridgeReq = _getBaseLancaBridgeReq();
        bridgeReq.dstChainGasLimit = dstChainGasLimit;

        vm.startPrank(sender);
        vm.expectRevert(ILancaBridge.InvalidDstChainGasLimit.selector);
        s_lancaBridge.bridge(bridgeReq);
        vm.stopPrank();
    }
}
