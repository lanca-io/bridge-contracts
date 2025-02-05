// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaParentPoolStorage} from "../storages/LancaParentPoolStorage.sol";
import {ILancaParentPool} from "../interfaces/ILancaParentPool.sol";
import {LancaOwnable} from "../../common/LancaOwnable.sol";
import {ZERO_ADDRESS} from "../../common/Constants.sol";
import {LibErrors} from "../../common/libraries/LibErrors.sol";

abstract contract LancaParentPoolStorageSetters is
    LancaParentPoolStorage,
    LancaOwnable,
    ILancaParentPool
{
    constructor(address owner) LancaOwnable(owner) {}

    function setEthersHashSum(bytes32 ethersHashSum) external payable onlyOwner {
        s_ethersHashSum = ethersHashSum;
    }

    function setGetBalanceJsCodeHashSum(bytes32 hashSum) external payable onlyOwner {
        s_getChildPoolsLiquidityJsCodeHashSum = hashSum;
    }

    /**
     * @notice Function to set the Cap of the Master pool.
     * @param newCap The new Cap of the pool
     */
    function setPoolCap(uint256 newCap) external payable onlyOwner {
        s_liquidityCap = newCap;
    }
}
