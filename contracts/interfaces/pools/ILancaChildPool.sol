// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILancaPool} from "./ILancaPool.sol";

interface ILancaChildPool is ILancaPool {
    function setPools(uint64 chainSelector, address pool) external payable;
    function ccipSendToPool(
        uint64 chainSelector,
        uint256 amountToSend,
        bytes32 withdrawalId
    ) external;
    function liquidatePool(bytes32 distributeLiquidityRequestId) external;
}
