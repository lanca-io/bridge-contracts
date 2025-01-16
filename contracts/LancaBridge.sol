// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICcip} from "./interfaces/ICcip.sol";
import {IConceroRouter} from "./interfaces/IConceroRouter.sol";
import {LancaBridgeStorage} from "./storages/LancaBridgeStorage.sol";
import {IRouterClient as ICcipRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client as LibCcipClient} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILancaBridge} from "./interfaces/ILancaBridge.sol";
import {ZERO_ADDRESS} from "./Constants.sol";

contract LancaBridge is ILancaBridge, LancaBridgeStorage {
    using SafeERC20 for IERC20;

    /* ERRORS */
    error InvalidBridgeToken();
    error InvalidReceiver();
    error InvalidDstChainGasLimit();
    error InsufficientBridgeAmount();
    error InvalidDstChainSelector();
    error InvalidFeeToken();

    /* EVENTS */
    event LancaBridgeSent(
        bytes32 indexed conceroMessageId,
        address token,
        uint256 amount,
        address receiver,
        uint64 dstChainSelector
    );

    event LancaSettlementSent(
        bytes32 indexed ccipMessageId,
        address token,
        uint256 amount,
        uint64 dstChainSelector
    );

    /* TYPES */

    struct CcipSettlementTxs {
        bytes32 id;
        bytes32 bridgeDataHash;
    }

    /* CONSTANTS */

    uint24 internal constant MAX_DST_CHAIN_GAS_LIMIT = 1_400_000;
    uint8 internal constant MAX_PENDING_SETTLEMENT_TXS_BY_LANE = 200;
    uint256 internal constant BATCHED_TX_THRESHOLD = 3_000 * 1e6;
    uint64 private constant CCIP_CALLBACK_GAS_LIMIT = 1_000_000;

    /* IMMUTABLES */

    address internal immutable i_usdc;
    IERC20 internal immutable i_link;
    IConceroRouter internal immutable i_conceroRouter;
    ICcipRouterClient internal immutable i_ccipRouter;

    constructor(address conceroRouter, address ccipRouter, address usdc, address link) {
        i_usdc = usdc;
        i_link = IERC20(link);
        i_conceroRouter = IConceroRouter(conceroRouter);
        i_ccipRouter = ICcipRouterClient(ccipRouter);
    }

    /* EXTERNAL FUNCTIONS */

    function bridge(BridgeData calldata bridgeData) external {
        _validateBridgeData(bridgeData);
        uint256 fee = _getFee(bridgeData);
        require(bridgeData.amount > fee, InsufficientBridgeAmount());

        IERC20(bridgeData.token).safeTransferFrom(msg.sender, address(this), bridgeData.amount);

        uint256 amountToSendAfterFee = bridgeData.amount - fee;
        address dstLancaBridgeContract = s_lancaBridgeContractsByChain[bridgeData.dstChainSelector];
        require(dstLancaBridgeContract != ZERO_ADDRESS, InvalidDstChainSelector());

        IConceroRouter.MessageRequest memory messageReq = IConceroRouter.MessageRequest({
            feeToken: i_usdc,
            receiver: dstLancaBridgeContract,
            dstChainSelector: bridgeData.dstChainSelector,
            dstChainGasLimit: bridgeData.dstChainGasLimit,
            data: bridgeData.message
        });

        bytes32 conceroMessageId = i_conceroRouter.sendMessage(messageReq);
        bytes32 bridgeDataHash = keccak256(
            abi.encode(
                bridgeData.amount,
                bridgeData.token,
                bridgeData.receiver,
                bridgeData.dstChainSelector,
                bridgeData.dstChainGasLimit,
                keccak256(bridgeData.message)
            )
        );
        uint256 updatedBatchedTxAmount = _addPendingSettlementTx(
            conceroMessageId,
            bridgeDataHash,
            amountToSendAfterFee,
            bridgeData.dstChainSelector
        );

        if (
            updatedBatchedTxAmount >= BATCHED_TX_THRESHOLD ||
            s_pendingSettlementIdsByDstChain[bridgeData.dstChainSelector].length >=
            MAX_PENDING_SETTLEMENT_TXS_BY_LANE
        ) {
            _sendBatchViaSettlement(
                bridgeData.token,
                updatedBatchedTxAmount,
                bridgeData.dstChainSelector
            );
        }

        emit LancaBridgeSent(
            conceroMessageId,
            bridgeData.token,
            amountToSendAfterFee,
            bridgeData.receiver,
            bridgeData.dstChainSelector
        );
    }

    function getFee(BridgeData calldata bridgeData) external view returns (uint256) {
        _validateBridgeData(bridgeData);
        return _getFee(bridgeData);
    }

    /* INTERNAL FUNCTIONS */

    function _validateBridgeData(BridgeData calldata bridgeData) internal view {
        require(bridgeData.token == i_usdc, InvalidBridgeToken());
        require(bridgeData.feeToken == i_usdc, InvalidFeeToken());
        require(bridgeData.receiver != ZERO_ADDRESS, InvalidReceiver());
        require(bridgeData.dstChainGasLimit <= MAX_DST_CHAIN_GAS_LIMIT, InvalidDstChainGasLimit());
    }

    function _getFee(BridgeData calldata bridgeData) internal view returns (uint256) {
        return 0;
    }

    function _addPendingSettlementTx(
        bytes32 conceroMessageId,
        bytes32 bridgeDataHash,
        uint256 amount,
        uint64 dstChainSelector
    ) internal returns (uint256) {
        s_pendingSettlementIdsByDstChain[dstChainSelector].push(conceroMessageId);
        s_pendingSettlementTxHashById[conceroMessageId] = bridgeDataHash;
        return s_pendingSettlementTxAmountByDstChain[dstChainSelector] += amount;
    }

    function _clearPendingSettlementTxByLane(uint64 dstChainSelector) internal {
        delete s_pendingSettlementIdsByDstChain[dstChainSelector];
        s_pendingSettlementTxAmountByDstChain[dstChainSelector] = 0;
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

        ICcip.CcipTxData memory ccipTxData = ICcip.CcipTxData({
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
            ccipSettlementTxs[i] = CcipSettlementTxs(
                pendingTxs[i],
                s_pendingSettlementTxHashById[pendingTxs[i]]
            );
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
        uint256 fees = i_ccipRouter.getFee(dstChainSelector, evm2AnyMessage);

        i_link.approve(address(i_ccipRouter), fees);
        IERC20(token).approve(address(i_ccipRouter), amount);
        s_lastCcipFeeInLink[dstChainSelector] = fees;

        return i_ccipRouter.ccipSend(dstChainSelector, evm2AnyMessage);
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
}
