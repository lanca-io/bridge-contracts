// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

abstract contract LancaOrchestratorStorage {
    mapping(uint64 dstChainSelector => address dstOrchetrator)
        internal s_lancaOrchestratorDstByChainSelector;

    mapping(address integrator => mapping(address token => uint256 amount))
        internal s_integratorFeesAmountByToken;

    /// @notice mapping to keep track of allowed routers to perform swaps.
    mapping(address router => bool isAllowed) public s_routerAllowed;

    /* GETTERS */
}
