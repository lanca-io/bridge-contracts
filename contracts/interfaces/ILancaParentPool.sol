// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface ILancaParentPool {
    event FailedExecutionLayerTxSettled(bytes32 indexed conceroMessageId);

    /// @notice Event emitted when a new withdrawal request is made.
    event WithdrawalRequestInitiated(bytes32 indexed requestId, address liquidityProvider);

    /// @notice Event emitted when a value is withdrawn from the contract.
    event WithdrawalCompleted(
        bytes32 indexed requestId,
        address indexed liquidityProvider,
        address token,
        uint256 amount
    );

    /// @notice Event emitted when a cross-chain transaction is received.
    event CCIPReceived(
        bytes32 indexed ccipMessageId,
        uint64 srcChainSelector,
        address sender,
        address token,
        uint256 amount
    );

    /// @notice Event emitted when a cross-chain message is sent.
    event CCIPSent(
        bytes32 indexed messageId,
        uint64 destinationChainSelector,
        address receiver,
        uint256 amount
    );

    /// @notice Event emitted in depositLiquidity when a deposit is successfully executed.
    event DepositInitiated(
        bytes32 indexed requestId,
        address indexed liquidityProvider,
        uint256 amount,
        uint256 deadline
    );

    /// @notice Event emitted when a deposit is completed.
    event DepositCompleted(
        bytes32 indexed requestId,
        address indexed liquidityProvider,
        uint256 amount,
        uint256 lpTokensToMint
    );
}

