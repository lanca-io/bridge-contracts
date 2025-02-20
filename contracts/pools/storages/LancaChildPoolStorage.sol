// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

abstract contract LancaChildPoolStorage {
    uint256 internal s_loansInUse;

    uint256[50] private __gap;

    uint64[] internal s_poolChainSelectors;

    mapping(uint64 chainSelector => mapping(address conceroContract => bool isAllowed))
        private s_isSenderContractAllowed_DEPRECATED;

    mapping(uint64 chainSelector => address pool) internal s_dstPoolByChainSelector;

    mapping(bytes32 requestId => bool isProcessed) internal s_distributeLiquidityRequestProcessed;

    mapping(bytes32 withdrawalId => bool isTriggered) internal s_isWithdrawalRequestTriggered;
}
