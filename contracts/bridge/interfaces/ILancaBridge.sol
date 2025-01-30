// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface ILancaBridge {
    /* TYPES */

    enum LancaBridgeMessageVersion {
        V1
    }

    struct CcipSettlementTxs {
        bytes32 id;
        address receiver;
        uint256 amount;
    }

    struct BridgeReq {
        uint256 amount;
        address token;
        address feeToken;
        address receiver;
        address fallbackReceiver;
        uint64 dstChainSelector;
        uint32 dstChainGasLimit;
        bytes message;
    }

    /* ERRORS */
    error InvalidBridgeToken();
    error InvalidReceiver();
    error InvalidDstChainGasLimit();
    error InsufficientBridgeAmount();
    error InvalidDstChainSelector();
    error InvalidFeeToken();
    error InvalidCcipToken();
    error InvalidLancaBridgeMessageVersion();
    error UnauthorizedConceroMessageSender();
    error UnauthorizedConceroMessageSrcChain();
    error UnauthorizedCcipMessageSender();
    error InvalidCcipTxType();

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
    event FailedExecutionLayerTxSettled(bytes32 indexed id);

    /* FUNCTIONS */
    function bridge(BridgeReq calldata bridgeReq) external;
}
