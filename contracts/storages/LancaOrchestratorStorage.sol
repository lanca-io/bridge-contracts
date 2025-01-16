// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

abstract contract LancaOrchestratorStorage {
    mapping(uint64 dstChainSelector => address dstOrchetrator)
        internal s_lancaOrchestratorDstByChainSelector;

    mapping(address integrator => mapping(address => uint256) tokens)
        internal s_integratorFeesAmountByToken;

    /* GETTERS */
}
