// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILancaPool} from "./ILancaPool.sol";

interface ILancaChildPool is ILancaPool {
    ///@notice error emitted if the array is empty.
    error NoPoolsToDistribute();
}
