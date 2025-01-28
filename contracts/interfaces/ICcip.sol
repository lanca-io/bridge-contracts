// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface ICcip {
    /// @notice CCIP transaction types
    enum CcipTxType {
        deposit,
        batchedSettlement,
        withdrawal,
        liquidityRebalancing
    }

    /// @notice CCIP Compatible Tokens
    enum CcipToken {
        bnm,
        usdc
    }

    /// @notice CCIP transaction data ie infraType with txIds, recipients, amounts
    // @dev md add msg version to ccip tx struct
    struct CcipSettleMessage {
        CcipTxType ccipTxType;
        bytes data;
    }
}
