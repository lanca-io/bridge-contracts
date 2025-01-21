// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaParentPoolStorage} from "../storages/LancaParentPoolStorage.sol";
import {LancaOwnable} from "../LancaOwnable.sol";

abstract contract LancaParentPoolStorageSetters is LancaParentPoolStorage, LancaOwnable {
    constructor(address owner) LancaOwnable(owner) {}

    /**
     * @notice Function to set the Ethers JS code for Chainlink Functions
     * @param ethersHashSum the JsCode
     * @dev this functions was used inside of ConceroFunctions
     */
    function setEthersHashSum(bytes32 ethersHashSum) external payable onlyOwner {
        s_ethersHashSum = ethersHashSum;
    }

    function setGetBalanceJsCodeHashSum(bytes32 hashSum) external payable onlyOwner {
        s_getChildPoolsLiquidityJsCodeHashSum = hashSum;
    }
}
