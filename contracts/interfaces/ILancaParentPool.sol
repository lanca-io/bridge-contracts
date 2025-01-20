// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface ILancaParentPool {
    event FailedExecutionLayerTxSettled(bytes32 indexed conceroMessageId);

    /// @notice event emitted when a new withdraw request is made
    event WithdrawalRequestInitiated(bytes32 indexed requestId, address liquidityProvider);

    /// @notice event emitted when a value is withdraw from the contract
    event WithdrawalCompleted(
        bytes32 indexed requestId,
        address indexed liquidityProvider,
        address token,
        uint256 amount
    );

    /// @notice event emitted when a Cross-chain tx is received.
    event CCIPReceived(
        bytes32 indexed ccipMessageId,
        uint64 srcChainSelector,
        address sender,
        address token,
        uint256 amount
    );

    /// @notice event emitted when a Cross-chain message is sent.
    event CCIPSent(
        bytes32 indexed messageId,
        uint64 destinationChainSelector,
        address receiver,
        uint256 amount
    );

    /// @notice event emitted in depositLiquidity when a deposit is successful executed
    event DepositInitiated(
        bytes32 indexed requestId,
        address indexed liquidityProvider,
        uint256 amount,
        uint256 deadline
    );

    /// @notice event emitted when a deposit is completed
    event DepositCompleted(
        bytes32 indexed requestId,
        address indexed liquidityProvider,
        uint256 amount,
        uint256 lpTokensToMint
    );
}
