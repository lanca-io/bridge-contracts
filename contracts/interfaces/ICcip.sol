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
    struct CcipTxData {
        CcipTxType ccipTxType;
        bytes data;
    }

    struct CcipSettlementTx {
        bytes32 id;
        uint256 amount;
        address recipient;
    }
}
