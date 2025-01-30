// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Client as LibCcipClient} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {ConceroClient} from "concero/contracts/ConceroClient/ConceroClient.sol";
import {ICcip} from "./interfaces/ICcip.sol";
import {IConceroRouter} from "./interfaces/IConceroRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILancaBridgeClient} from "./LancaBridgeClient/Interfaces/ILancaBridgeClient.sol";
import {ILancaBridge} from "./interfaces/ILancaBridge.sol";
import {IRouterClient as ICcipRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LancaBridgeStorage} from "./storages/LancaBridgeStorage.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ZERO_ADDRESS} from "./Constants.sol";
import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {ILancaPool} from "./interfaces/pools/ILancaPool.sol";

contract LancaBridge is LancaBridgeStorage, CCIPReceiver, ConceroClient, ILancaBridge {
    using SafeERC20 for IERC20;

    /* CONSTANTS */
    uint256 internal constant LANCA_FEE_FACTOR = 1_000;
    uint24 internal constant MAX_DST_CHAIN_GAS_LIMIT = 1_400_000;
    uint8 internal constant MAX_PENDING_SETTLEMENT_TXS_BY_LANE = 200;
    uint256 internal constant BATCHED_TX_THRESHOLD = 3_000 * 1e6;
    uint64 private constant CCIP_CALLBACK_GAS_LIMIT = 1_000_000;
    uint256 private constant STANDARD_TOKEN_DECIMALS = 1e18;

    /* IMMUTABLES */

    address internal immutable i_usdc;
    IERC20 internal immutable i_link;
    ILancaPool internal immutable i_lancaPool;

    constructor(
        address conceroRouter,
        address ccipRouter,
        address usdc,
        address link,
        address lancaPool
    ) ConceroClient(conceroRouter) CCIPReceiver(ccipRouter) {
        i_usdc = usdc;
        i_link = IERC20(link);
        i_lancaPool = ILancaPool(lancaPool);
    }

    /* EXTERNAL FUNCTIONS */

    function bridge(BridgeReq calldata bridgeReq) external {
        _validateBridgeReq(bridgeReq);
        uint256 fee = _getFee(bridgeReq);
        require(bridgeReq.amount > fee, InsufficientBridgeAmount());

        IERC20(bridgeReq.token).safeTransferFrom(msg.sender, address(this), bridgeReq.amount);

        uint256 amountToSendAfterFee = bridgeReq.amount - fee;
        address dstLancaBridgeContract = s_lancaBridgeContractsByChain[bridgeReq.dstChainSelector];
        require(dstLancaBridgeContract != ZERO_ADDRESS, InvalidDstChainSelector());

        bytes memory bridgeDataMessage = abi.encode(
            LancaBridgeMessageVersion.V1,
            msg.sender,
            bridgeReq.receiver,
            uint24(bridgeReq.dstChainGasLimit),
            bridgeReq.amount,
            bridgeReq.message
        );

        IConceroRouter.MessageRequest memory messageReq = IConceroRouter.MessageRequest({
            feeToken: i_usdc,
            receiver: dstLancaBridgeContract,
            dstChainSelector: bridgeReq.dstChainSelector,
            dstChainGasLimit: bridgeReq.dstChainGasLimit,
            data: bridgeDataMessage
        });

        bytes32 conceroMessageId = IConceroRouter(getConceroRouter()).sendMessage(messageReq);

        uint256 updatedBatchedTxAmount = _addPendingSettlementTx(
            conceroMessageId,
            bridgeReq.fallbackReceiver,
            amountToSendAfterFee,
            bridgeReq.dstChainSelector
        );

        if (
            updatedBatchedTxAmount >= BATCHED_TX_THRESHOLD ||
            s_pendingSettlementIdsByDstChain[bridgeReq.dstChainSelector].length >=
            MAX_PENDING_SETTLEMENT_TXS_BY_LANE
        ) {
            _sendBatchViaSettlement(
                bridgeReq.token,
                updatedBatchedTxAmount,
                bridgeReq.dstChainSelector
            );
        }

        emit LancaBridgeSent(
            conceroMessageId,
            bridgeReq.token,
            amountToSendAfterFee,
            bridgeReq.receiver,
            bridgeReq.dstChainSelector
        );
    }

    function getFee(BridgeReq calldata bridgeReq) external view returns (uint256) {
        _validateBridgeReq(bridgeReq);
        return _getFee(bridgeReq);
    }

    /* PUBLIC FUNCTIONS */
    /**
     * @notice Function to get the total amount of CCIP fees in USDC
     * @param dstChainSelector the destination blockchain chain selector
     */

    function getBridgeFees(
        uint64 dstChainSelector,
        uint256 amount
    ) public view returns (uint256, uint256, uint256) {
        uint256 ccipFee = _getCCIPFee(dstChainSelector, amount);
        uint256 lancaFee = _getLancaFee(amount);
        uint256 messengerFee = IConceroRouter(getConceroRouter()).getFee(dstChainSelector);
        return (ccipFee, lancaFee, messengerFee);
    }

    /* INTERNAL FUNCTIONS */

    function _getCCIPFee(uint64 dstChainSelector, uint256 amount) internal view returns (uint256) {
        uint256 ccipFeeInUsdc = _getCCIPFeeInUsdc(dstChainSelector);
        return _calculateProportionalCCIPFee(ccipFeeInUsdc, amount);
    }

    function _getLancaFee(uint256 amount) internal pure returns (uint256) {
        return amount / LANCA_FEE_FACTOR;
    }

    function _getCCIPFeeInUsdc(uint64 dstChainSelector) internal view returns (uint256) {
        uint256 ccipFeeInLink = s_lastCcipFeeInLink[dstChainSelector];
        return (ccipFeeInLink * s_latestLinkUsdcRate) / STANDARD_TOKEN_DECIMALS;
    }

    function _validateBridgeReq(BridgeReq calldata bridgeReq) internal view {
        require(bridgeReq.token == i_usdc, InvalidBridgeToken());
        require(bridgeReq.feeToken == i_usdc, InvalidFeeToken());
        require(bridgeReq.receiver != ZERO_ADDRESS, InvalidReceiver());
        require(bridgeReq.dstChainGasLimit <= MAX_DST_CHAIN_GAS_LIMIT, InvalidDstChainGasLimit());
    }

    function _getFee(BridgeReq calldata bridgeReq) internal view returns (uint256) {
        (uint256 ccipFee, uint256 lancaFee, uint256 messengerFee) = getBridgeFees(
            bridgeReq.dstChainSelector,
            bridgeReq.amount
        );
        return ccipFee + lancaFee + messengerFee;
    }

    function _addPendingSettlementTx(
        bytes32 conceroMessageId,
        address fallbackReceiver,
        uint256 amount,
        uint64 dstChainSelector
    ) internal returns (uint256) {
        s_pendingSettlementIdsByDstChain[dstChainSelector].push(conceroMessageId);
        PendingSettlementTx memory settlementTx = PendingSettlementTx({
            receiver: fallbackReceiver,
            amount: amount
        });
        s_pendingSettlementTxById[conceroMessageId] = settlementTx;
        return s_pendingSettlementTxAmountByDstChain[dstChainSelector] += amount;
    }

    function _clearPendingSettlementTxByLane(uint64 dstChainSelector) internal {
        delete s_pendingSettlementIdsByDstChain[dstChainSelector];
        delete s_pendingSettlementTxAmountByDstChain[dstChainSelector];
    }

    function _sendBatchViaSettlement(
        address token,
        uint256 amount,
        uint64 dstChainSelector
    ) internal {
        CcipSettlementTxs[] memory ccipSettlementTxs = _getSettlementPendingTxsByDstChain(
            dstChainSelector
        );

        _clearPendingSettlementTxByLane(dstChainSelector);

        ICcip.CcipSettleMessage memory ccipTxData = ICcip.CcipSettleMessage({
            ccipTxType: ICcip.CcipTxType.batchedSettlement,
            data: abi.encode(ccipSettlementTxs)
        });

        bytes32 ccipMessageId = _sendCcipPayLink(
            dstChainSelector,
            token,
            amount,
            abi.encode(ccipTxData)
        );

        emit LancaSettlementSent(ccipMessageId, token, amount, dstChainSelector);
    }

    function _getSettlementPendingTxsByDstChain(
        uint64 dstChainSelector
    ) internal view returns (CcipSettlementTxs[] memory) {
        bytes32[] memory pendingTxs = s_pendingSettlementIdsByDstChain[dstChainSelector];
        uint256 pendingTxsLength = pendingTxs.length;
        CcipSettlementTxs[] memory ccipSettlementTxs = new CcipSettlementTxs[](pendingTxsLength);

        for (uint256 i; i < pendingTxsLength; ++i) {
            ccipSettlementTxs[i] = CcipSettlementTxs({
                id: pendingTxs[i],
                receiver: s_pendingSettlementTxById[pendingTxs[i]].receiver,
                amount: s_pendingSettlementTxById[pendingTxs[i]].amount
            });
        }

        return ccipSettlementTxs;
    }

    function _sendCcipPayLink(
        uint64 dstChainSelector,
        address token,
        uint256 amount,
        bytes memory ccipMessageData
    ) internal returns (bytes32) {
        LibCcipClient.EVM2AnyMessage memory evm2AnyMessage = _buildCcipMessage(
            dstChainSelector,
            token,
            address(i_link),
            amount,
            ccipMessageData
        );
        uint256 fees = ICcipRouterClient(i_ccipRouter).getFee(dstChainSelector, evm2AnyMessage);

        i_link.approve(address(i_ccipRouter), fees);
        IERC20(token).approve(address(i_ccipRouter), amount);
        s_lastCcipFeeInLink[dstChainSelector] = fees;

        return ICcipRouterClient(i_ccipRouter).ccipSend(dstChainSelector, evm2AnyMessage);
    }

    function _buildCcipMessage(
        uint64 dstChainSelector,
        address token,
        address feeToken,
        uint256 amount,
        bytes memory ccipMessageData
    ) internal view returns (LibCcipClient.EVM2AnyMessage memory) {
        address receiver = s_lancaBridgeContractsByChain[dstChainSelector];
        require(receiver != ZERO_ADDRESS, InvalidDstChainSelector());

        LibCcipClient.EVMTokenAmount[] memory tokenAmounts = new LibCcipClient.EVMTokenAmount[](1);
        tokenAmounts[0] = LibCcipClient.EVMTokenAmount({token: token, amount: amount});

        return
            LibCcipClient.EVM2AnyMessage({
                receiver: abi.encode(receiver),
                data: ccipMessageData,
                tokenAmounts: tokenAmounts,
                extraArgs: LibCcipClient._argsToBytes(
                    LibCcipClient.EVMExtraArgsV1({gasLimit: CCIP_CALLBACK_GAS_LIMIT})
                ),
                feeToken: feeToken
            });
    }

    /**
     * @notice Function to calculate the proportional CCIP fee based on the amount
     * @param ccipFeeInUsdc the total CCIP fee for a full batch
     * @param amount the amount of USDC being transferred
     */
    function _calculateProportionalCCIPFee(
        uint256 ccipFeeInUsdc,
        uint256 amount
    ) internal pure returns (uint256) {
        if (amount >= BATCHED_TX_THRESHOLD) return ccipFeeInUsdc;
        return (ccipFeeInUsdc * amount) / BATCHED_TX_THRESHOLD;
    }

    /* CONCERO CLIENT FUNCTIONS */

    function _conceroReceive(Message calldata conceroMessage) internal override {
        // @TODO: search if confirmed mapping needed on this step
        require(
            s_isConceroMessageSenderAllowed[conceroMessage.sender],
            UnauthorizedConceroMessageSender()
        );

        require(
            s_isConceroMessageSrcChainAllowed[conceroMessage.srcChainSelector],
            UnauthorizedConceroMessageSrcChain()
        );

        LancaBridgeMessageVersion lancaBridgeMessageVersion = LancaBridgeMessageVersion(
            uint8(conceroMessage.data[0])
        );

        if (lancaBridgeMessageVersion == LancaBridgeMessageVersion.V1) {
            _handleLancaBridgeMessageV1(conceroMessage);
        } else {
            revert InvalidLancaBridgeMessageVersion();
        }
    }

    function _handleLancaBridgeMessageV1(Message calldata conceroMessage) internal {
        (
            ,
            address sender,
            address lancaBridgeReceiver,
            uint24 gasLimit,
            uint256 amount,
            bytes memory data
        ) = abi.decode(conceroMessage.data, (uint8, address, address, uint24, uint256, bytes));

        ILancaBridgeClient.LancaBridgeData memory bridgeData = ILancaBridgeClient.LancaBridgeData({
            id: conceroMessage.id,
            sender: sender,
            token: i_usdc,
            amount: amount,
            srcChainSelector: conceroMessage.srcChainSelector,
            data: data
        });

        // @dev TODO: take loan from lanca pool instead transfer
        IERC20(i_usdc).safeTransfer(lancaBridgeReceiver, amount);
        ILancaBridgeClient(lancaBridgeReceiver).lancaBridgeReceive{gas: gasLimit}(bridgeData);
    }

    /* CCIP CLIENT FUNCTIONS */

    function _ccipReceive(LibCcipClient.Any2EVMMessage memory ccipMessage) internal override {
        // @dev mb pack it into one sload
        require(
            s_isCcipMessageSenderAllowed[abi.decode(ccipMessage.sender, (address))],
            UnauthorizedCcipMessageSender()
        );
        require(
            s_isCcipMessageSrcChainAllowed[ccipMessage.sourceChainSelector],
            UnauthorizedCcipMessageSender()
        );

        address receivedToken = ccipMessage.destTokenAmounts[0].token;
        require(receivedToken == i_usdc, InvalidCcipToken());

        ICcip.CcipSettleMessage memory ccipTx = abi.decode(
            ccipMessage.data,
            (ICcip.CcipSettleMessage)
        );

        if (ccipTx.ccipTxType == ICcip.CcipTxType.batchedSettlement) {
            _handleCcipBatchedSettlement(ccipMessage.messageId, ccipTx);
        } else {
            revert InvalidCcipTxType();
        }
    }

    function _handleCcipBatchedSettlement(
        bytes32 ccipMessageId,
        ICcip.CcipSettleMessage memory ccipSettleMessage
    ) internal {
        CcipSettlementTxs[] memory ccipSettlementTxs = abi.decode(
            ccipSettleMessage.data,
            (CcipSettlementTxs[])
        );

        uint256 rebalancedAmount;

        for (uint256 i; i < ccipSettlementTxs.length; ++i) {
            bytes32 txId = ccipSettlementTxs[i].id;
            uint256 txAmount = ccipSettlementTxs[i].amount;

            if (s_isBridgeProcessed[txId]) {
                rebalancedAmount += txAmount;
            } else {
                s_isBridgeProcessed[txId] = true;
                IERC20(i_usdc).safeTransfer(ccipSettlementTxs[i].receiver, txAmount);

                emit FailedExecutionLayerTxSettled(txId);
            }
        }

        if (rebalancedAmount > 0) {
            IERC20(i_usdc).safeTransfer(msg.sender, rebalancedAmount);
            i_lancaPool.completeRebalancing(ccipMessageId, rebalancedAmount);
        }
    }
}
