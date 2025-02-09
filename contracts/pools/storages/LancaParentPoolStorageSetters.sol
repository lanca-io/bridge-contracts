// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaParentPoolStorage} from "../storages/LancaParentPoolStorage.sol";
import {ILancaParentPool} from "../interfaces/ILancaParentPool.sol";
import {LancaOwnable} from "../../common/LancaOwnable.sol";

abstract contract LancaParentPoolStorageSetters is
    LancaParentPoolStorage,
    LancaOwnable,
    ILancaParentPool
{
    constructor(address owner) LancaOwnable(owner) {}

    /**
     * @notice Function to set the Cap of the Master pool.
     * @param newCap The new Cap of the pool
     */
    function setPoolCap(uint256 newCap) external payable onlyOwner {
        s_liquidityCap = newCap;
    }
}
