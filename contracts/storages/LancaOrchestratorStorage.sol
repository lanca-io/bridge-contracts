// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

abstract contract LancaOrchestratorStorage is ReentrancyGuard {
    mapping(uint64 dstChainSelector => address dstOrchetrator)
        internal s_lancaOrchestratorDstByChainSelector;

    mapping(address integrator => mapping(address token => uint256 amount))
        internal s_integratorFeesAmountByToken;

    /* GETTERS */

    /// @notice mapping to keep track of allowed routers to perform swaps.
    mapping(address router => bool isAllowed) public s_routerAllowed;

    /// @notice mapping of chainId to USDC address
    mapping(uint64 chainId => address usdc) public s_usdcAddressByChainId;
}
