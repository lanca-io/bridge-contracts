// SPDX-License-Identifier: UNLICENSED
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
import {ICcip} from "contracts/common/interfaces/ICcip.sol";
import {Client as LibCcipClient} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {ZERO_ADDRESS} from "contracts/common/Constants.sol";

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
            (amount > (s_lancaBridge.exposed_getBatchedTxThreshold() + 1 * USDC_DECIMALS)) &&
                (amount < 1_000_000_000_000 * USDC_DECIMALS)
        );

        address sender = makeAddr("sender");

        ILancaBridge.BridgeReq memory bridgeReq = _getBaseLancaBridgeReq();
        bridgeReq.amount = amount;
        deal(bridgeReq.token, sender, amount);

        uint256 senderBalanceBefore = IERC20(bridgeReq.token).balanceOf(sender);

        vm.startPrank(sender);

        IERC20(bridgeReq.token).approve(address(s_lancaBridge), amount);

        (uint256 ccipFee, uint256 lancaFee, ) = s_lancaBridge.getBridgeFeeBreakdown(
            bridgeReq.dstChainSelector,
            bridgeReq.amount,
            bridgeReq.feeToken,
            bridgeReq.dstChainGasLimit
        );

        s_lancaBridge.bridge(bridgeReq);
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
            abi.encode(
                ILancaBridge.LancaBridgeMessageDataV1({
                    sender: lancaBridgeSender,
                    receiver: lancaBridgeReceiver,
                    dstChainSelector: s_chainSelectorArb,
                    dstChainGasLimit: gasLimit,
                    amount: amount,
                    data: lancaBridgeMessageData
                })
            )
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

    function test_ccipReceiveSettlementWithoutExecutionLayerFails() public {
        address receiver0 = makeAddr("receiver 0");
        address receiver1 = makeAddr("receiver 1");
        address receiver2 = makeAddr("receiver 2");

        ILancaBridge.CcipSettlementTxs[]
            memory ccipSettlementTxs = new ILancaBridge.CcipSettlementTxs[](3);

        ccipSettlementTxs[0] = ILancaBridge.CcipSettlementTxs({
            id: keccak256("ccip settlement tx 0"),
            receiver: receiver0,
            amount: 100 * USDC_DECIMALS
        });

        ccipSettlementTxs[1] = ILancaBridge.CcipSettlementTxs({
            id: keccak256("ccip settlement tx 1"),
            receiver: receiver1,
            amount: 200 * USDC_DECIMALS
        });

        ccipSettlementTxs[2] = ILancaBridge.CcipSettlementTxs({
            id: keccak256("ccip settlement tx 2"),
            receiver: receiver2,
            amount: 300 * USDC_DECIMALS
        });

        ICcip.CcipSettleMessage memory ccipTxs = ICcip.CcipSettleMessage({
            ccipTxType: ICcip.CcipTxType.batchedSettlement,
            data: abi.encode(ccipSettlementTxs)
        });

        LibCcipClient.EVMTokenAmount[] memory destTokenAmounts = new LibCcipClient.EVMTokenAmount[](
            1
        );

        destTokenAmounts[0].token = s_usdc;

        for (uint256 i; i < ccipSettlementTxs.length; ++i) {
            destTokenAmounts[0].amount += ccipSettlementTxs[i].amount;
            s_lancaBridge.exposed_setIsBridgeProcessed(ccipSettlementTxs[i].id);
        }

        uint256 lancaPoolBalanceBefore = IERC20(s_usdc).balanceOf(
            s_lancaBridge.exposed_getLancaPool()
        );

        deal(s_usdc, address(s_lancaBridge), destTokenAmounts[0].amount);

        LibCcipClient.Any2EVMMessage memory ccipMessage = LibCcipClient.Any2EVMMessage({
            messageId: keccak256("ccip message id"),
            sourceChainSelector: s_chainSelectorArb,
            sender: abi.encode(s_lancaBridgeArb),
            data: abi.encode(ccipTxs),
            destTokenAmounts: destTokenAmounts
        });

        vm.prank(s_lancaBridge.getRouter());
        s_lancaBridge.ccipReceive(ccipMessage);

        uint256 lancaPoolBalanceAfter = IERC20(s_usdc).balanceOf(
            s_lancaBridge.exposed_getLancaPool()
        );

        assertEq(lancaPoolBalanceAfter, lancaPoolBalanceBefore + destTokenAmounts[0].amount);
    }

    function test_ccipReceiveSettlementWithExecutionLayerFails() public {
        address receiver0 = makeAddr("receiver 0");
        address receiver1 = makeAddr("receiver 1");
        address receiver2 = makeAddr("receiver 2");
        uint256 failedTxIndex = 1;

        ILancaBridge.CcipSettlementTxs[]
            memory ccipSettlementTxs = new ILancaBridge.CcipSettlementTxs[](3);

        ccipSettlementTxs[0] = ILancaBridge.CcipSettlementTxs({
            id: keccak256("ccip settlement tx 0"),
            receiver: receiver0,
            amount: 100 * USDC_DECIMALS
        });

        ccipSettlementTxs[1] = ILancaBridge.CcipSettlementTxs({
            id: keccak256("ccip settlement tx 1"),
            receiver: receiver1,
            amount: 200 * USDC_DECIMALS
        });

        ccipSettlementTxs[2] = ILancaBridge.CcipSettlementTxs({
            id: keccak256("ccip settlement tx 2"),
            receiver: receiver2,
            amount: 300 * USDC_DECIMALS
        });

        ICcip.CcipSettleMessage memory ccipTxs = ICcip.CcipSettleMessage({
            ccipTxType: ICcip.CcipTxType.batchedSettlement,
            data: abi.encode(ccipSettlementTxs)
        });

        LibCcipClient.EVMTokenAmount[] memory destTokenAmounts = new LibCcipClient.EVMTokenAmount[](
            1
        );

        destTokenAmounts[0].token = s_usdc;

        for (uint256 i; i < ccipSettlementTxs.length; ++i) {
            destTokenAmounts[0].amount += ccipSettlementTxs[i].amount;
            if (i != failedTxIndex) {
                s_lancaBridge.exposed_setIsBridgeProcessed(ccipSettlementTxs[i].id);
            }
        }

        uint256 receiver1BalanceBefore = IERC20(s_usdc).balanceOf(receiver1);
        uint256 lancaPoolBalanceBefore = IERC20(s_usdc).balanceOf(
            s_lancaBridge.exposed_getLancaPool()
        );

        deal(s_usdc, address(s_lancaBridge), destTokenAmounts[0].amount);

        LibCcipClient.Any2EVMMessage memory ccipMessage = LibCcipClient.Any2EVMMessage({
            messageId: keccak256("ccip message id"),
            sourceChainSelector: s_chainSelectorArb,
            sender: abi.encode(s_lancaBridgeArb),
            data: abi.encode(ccipTxs),
            destTokenAmounts: destTokenAmounts
        });

        vm.prank(s_lancaBridge.getRouter());
        s_lancaBridge.ccipReceive(ccipMessage);

        uint256 lancaPoolBalanceAfter = IERC20(s_usdc).balanceOf(
            s_lancaBridge.exposed_getLancaPool()
        );

        assertEq(
            lancaPoolBalanceAfter,
            lancaPoolBalanceBefore +
                destTokenAmounts[0].amount -
                ccipSettlementTxs[failedTxIndex].amount
        );

        uint256 receiver1BalanceAfter = IERC20(s_usdc).balanceOf(receiver1);

        assertEq(
            receiver1BalanceAfter,
            receiver1BalanceBefore + ccipSettlementTxs[failedTxIndex].amount
        );

        // @dev check that the failed tx was proceed by the settlement
        for (uint256 i; i < ccipSettlementTxs.length; ++i) {
            assertEq(s_lancaBridge.exposed_isBridgeProcessed(ccipSettlementTxs[i].id), true);
        }
    }

    /* REVERTS */

    /* BRIDGE */

    function testFuzz_bridgeInvalidBridgeToken_revert(address bridgeToken) public {
        vm.assume(bridgeToken != s_usdc);

        address sender = makeAddr("sender");

        ILancaBridge.BridgeReq memory bridgeReq = _getBaseLancaBridgeReq();
        bridgeReq.token = bridgeToken;

        vm.startPrank(sender);
        vm.expectRevert(ILancaBridge.InvalidBridgeToken.selector);
        s_lancaBridge.bridge(bridgeReq);
        vm.stopPrank();
    }

    function testFuzz_bridgeInvalidFeeToken_revert(address feeToken) public {
        vm.assume(feeToken != s_usdc);
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
        address receiver = ZERO_ADDRESS;

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

    function test_bridgeInsufficientBridgeAmount_revert() public {
        uint256 amount = 1;
        ILancaBridge.BridgeReq memory bridgeReq = _getBaseLancaBridgeReq();
        bridgeReq.amount = amount;

        vm.expectRevert(ILancaBridge.InsufficientBridgeAmount.selector);
        s_lancaBridge.bridge(bridgeReq);
    }

    function test_bridgeInvalidDstChainSelector_revert() public {
        address sender = makeAddr("sender");
        deal(s_usdc, sender, 100 * USDC_DECIMALS);
        ILancaBridge.BridgeReq memory bridgeReq = _getBaseLancaBridgeReq();

        s_lancaBridge.exposed_setLancaBridgeContractsByChain(s_chainSelectorArb, ZERO_ADDRESS);

        vm.prank(sender);
        IERC20(bridgeReq.token).approve(address(s_lancaBridge), bridgeReq.amount);

        vm.prank(sender);
        vm.expectRevert(ILancaBridge.InvalidDstChainSelector.selector);
        s_lancaBridge.bridge(bridgeReq);
    }

    /* CONCERO RECEIVE */

    function testFuzz_conceroReceiveUnauthorizedConceroMessageSender_revert(address sender) public {
        IConceroClient.Message memory conceroMessage = _getBaseConceroMessage();
        conceroMessage.sender = sender;

        vm.prank(s_lancaBridge.getConceroRouter());
        vm.expectRevert(ILancaBridge.UnauthorizedConceroMessageSender.selector);
        s_lancaBridge.conceroReceive(conceroMessage);
    }

    function test_conceroReceiveInvalidLancaBridgeMessageVersion_revert() public {
        address lancaBridgeSender = makeAddr("lanca bridge sender");
        address lancaBridgeReceiver = address(new LancaBridgeClientMock(address(s_lancaBridge)));
        uint24 gasLimit = 1_000_000;
        uint256 amount = 530 * USDC_DECIMALS;
        bytes memory lancaBridgeMessageData = new bytes(300);

        bytes memory lancaBridgeMessage = abi.encode(
            ILancaBridge.LancaBridgeMessageVersion.V2,
            abi.encode(
                ILancaBridge.LancaBridgeMessageDataV1({
                    sender: lancaBridgeSender,
                    receiver: lancaBridgeReceiver,
                    dstChainSelector: s_chainSelectorArb,
                    dstChainGasLimit: gasLimit,
                    amount: amount,
                    data: lancaBridgeMessageData
                })
            )
        );

        IConceroClient.Message memory conceroMessage = _getBaseConceroMessage();
        conceroMessage.sender = s_lancaBridgeArb;
        conceroMessage.data = lancaBridgeMessage;

        vm.prank(s_lancaBridge.getConceroRouter());
        vm.expectRevert(ILancaBridge.InvalidLancaBridgeMessageVersion.selector);
        s_lancaBridge.conceroReceive(conceroMessage);
    }

    function test_conceroReceiveBridgeAlreadyProcessed_revert() public {
        address lancaBridgeSender = makeAddr("lanca bridge sender");
        address lancaBridgeReceiver = address(new LancaBridgeClientMock(address(s_lancaBridge)));
        uint24 gasLimit = 1_000_000;
        uint256 amount = 530 * USDC_DECIMALS;
        bytes memory lancaBridgeMessageData = new bytes(300);

        bytes memory lancaBridgeMessage = abi.encode(
            ILancaBridge.LancaBridgeMessageVersion.V1,
            abi.encode(
                ILancaBridge.LancaBridgeMessageDataV1({
                    sender: lancaBridgeSender,
                    receiver: lancaBridgeReceiver,
                    dstChainSelector: s_chainSelectorArb,
                    dstChainGasLimit: gasLimit,
                    amount: amount,
                    data: lancaBridgeMessageData
                })
            )
        );

        IConceroClient.Message memory conceroMessage = _getBaseConceroMessage();
        conceroMessage.sender = s_lancaBridgeArb;
        conceroMessage.data = lancaBridgeMessage;

        vm.startPrank(s_lancaBridge.getConceroRouter());
        s_lancaBridge.conceroReceive(conceroMessage);

        vm.expectRevert(ILancaBridge.BridgeAlreadyProcessed.selector);
        s_lancaBridge.conceroReceive(conceroMessage);
        vm.stopPrank();
    }

    function test_ccipReceiveUnauthorizedCcipSender_revert() public {
        LibCcipClient.Any2EVMMessage memory ccipMessage = LibCcipClient.Any2EVMMessage({
            messageId: keccak256("ccip message id"),
            sourceChainSelector: s_chainSelectorArb,
            sender: abi.encode(makeAddr("unauthorized ccip message sender")),
            data: new bytes(0),
            destTokenAmounts: new LibCcipClient.EVMTokenAmount[](0)
        });

        vm.prank(s_lancaBridge.getRouter());
        vm.expectRevert(ILancaBridge.UnauthorizedCcipMessageSender.selector);
        s_lancaBridge.ccipReceive(ccipMessage);
    }

    function test_ccipReceiveUnauthorizedCcipSrcChainSelector_revert() public {
        LibCcipClient.Any2EVMMessage memory ccipMessage = LibCcipClient.Any2EVMMessage({
            messageId: keccak256("ccip message id"),
            sourceChainSelector: uint64(2),
            sender: abi.encode(s_lancaBridgeArb),
            data: new bytes(0),
            destTokenAmounts: new LibCcipClient.EVMTokenAmount[](0)
        });

        vm.prank(s_lancaBridge.getRouter());
        vm.expectRevert(ILancaBridge.UnauthorizedCcipMessageSender.selector);
        s_lancaBridge.ccipReceive(ccipMessage);
    }

    function test_ccipReceiveInvalidCcipTxType_revert() public {
        ICcip.CcipSettleMessage memory ccipTxs = ICcip.CcipSettleMessage({
            ccipTxType: ICcip.CcipTxType.withdrawal,
            data: new bytes(0)
        });

        LibCcipClient.EVMTokenAmount[] memory destTokenAmounts = new LibCcipClient.EVMTokenAmount[](
            1
        );
        destTokenAmounts[0].token = s_usdc;

        LibCcipClient.Any2EVMMessage memory ccipMessage = LibCcipClient.Any2EVMMessage({
            messageId: keccak256("ccip message id"),
            sourceChainSelector: s_chainSelectorArb,
            sender: abi.encode(s_lancaBridgeArb),
            data: abi.encode(ccipTxs),
            destTokenAmounts: destTokenAmounts
        });

        vm.prank(s_lancaBridge.getRouter());
        vm.expectRevert(ILancaBridge.InvalidCcipTxType.selector);
        s_lancaBridge.ccipReceive(ccipMessage);
    }

    function test_ccipReceiveInvalidCcipToken_revert() public {
        ICcip.CcipSettleMessage memory ccipTxs = ICcip.CcipSettleMessage({
            ccipTxType: ICcip.CcipTxType.withdrawal,
            data: new bytes(0)
        });

        LibCcipClient.EVMTokenAmount[] memory destTokenAmounts = new LibCcipClient.EVMTokenAmount[](
            1
        );
        destTokenAmounts[0].token = makeAddr("wrong token");

        LibCcipClient.Any2EVMMessage memory ccipMessage = LibCcipClient.Any2EVMMessage({
            messageId: keccak256("ccip message id"),
            sourceChainSelector: s_chainSelectorArb,
            sender: abi.encode(s_lancaBridgeArb),
            data: abi.encode(ccipTxs),
            destTokenAmounts: destTokenAmounts
        });

        vm.prank(s_lancaBridge.getRouter());
        vm.expectRevert(ILancaBridge.InvalidCcipToken.selector);
        s_lancaBridge.ccipReceive(ccipMessage);
    }
}
