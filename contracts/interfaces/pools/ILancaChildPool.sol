// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILancaPool} from "./ILancaPool.sol";

interface ILancaChildPool is ILancaPool {
    /* EVENTS */
    event FailedExecutionLayerTxSettled(bytes32 indexed conceroMessageId);
    ///@notice event emitted when a Cross-chain tx is received.
    event CCIPReceived(
        bytes32 indexed ccipMessageId,
        uint64 srcChainSelector,
        address sender,
        address token,
        uint256 amount
    );
    ///@notice event emitted when a Cross-chain message is sent.
    event CCIPSent(
        bytes32 indexed messageId,
        uint64 destinationChainSelector,
        address receiver,
        address linkToken,
        uint256 fees
    );

    ///@notice error emitted if the array is empty.
    error NoPoolsToDistribute();
    error DistributeLiquidityRequestAlreadyProceeded(bytes32 reqId);
    error WithdrawalAlreadyTriggered();

    function setPools(uint64 chainSelector, address pool) external payable;
    function ccipSendToPool(
        uint64 chainSelector,
        uint256 amountToSend,
        bytes32 withdrawalId
    ) external;
    function liquidatePool(bytes32 distributeLiquidityRequestId) external;
}
