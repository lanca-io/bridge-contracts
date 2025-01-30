// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface ILancaBridgeStorage {
    struct PendingSettlementTx {
        address receiver;
        uint256 amount;
    }
}
