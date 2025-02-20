// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

abstract contract LancaOrchestratorStorage is ReentrancyGuard {
    mapping(uint64 dstChainSelector => address dstLancaOrchestrator)
        internal s_lancaOrchestratorDstByChainSelector;

    // @notice integration mappings
    mapping(address integrator => mapping(address token => uint256 amount))
        internal s_integratorFeesAmountByToken;
    mapping(address token => uint256 amount) internal s_totalIntegratorFeesAmountByToken;

    /// @notice mapping to keep track of allowed routers to perform swaps.
    mapping(address router => bool isAllowed) internal s_routerAllowed;

    /* GETTERS */

    function getLancaOrchestratorByChain(uint64 dstChainSelector) external view returns (address) {
        return s_lancaOrchestratorDstByChainSelector[dstChainSelector];
    }

    function isDexRouterAllowed(address router) external view returns (bool) {
        return s_routerAllowed[router];
    }

    function getIntegratorFeeAmount(
        address integrator,
        address token
    ) external view returns (uint256) {
        return s_integratorFeesAmountByToken[integrator][token];
    }
}
