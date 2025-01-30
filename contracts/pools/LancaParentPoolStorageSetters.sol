// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaParentPoolStorage} from "../storages/LancaParentPoolStorage.sol";
import {ILancaParentPool} from "../interfaces/pools/ILancaParentPool.sol";
import {LancaOwnable} from "../LancaOwnable.sol";
import {ZERO_ADDRESS} from "../Constants.sol";
import {LibErrors} from "../libraries/LibErrors.sol";

abstract contract LancaParentPoolStorageSetters is
    LancaParentPoolStorage,
    LancaOwnable,
    ILancaParentPool
{
    using LibErrors for *;

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

    /**
     * @notice function to manage the Cross-chains Concero contracts
     * @param chainSelector chain identifications
     * @param contractAddress address of the Cross-chains Concero contracts
     * @param isAllowed bool to allow or disallow the contract
     * @dev only owner can call it
     * @dev it's payable to save some gas.
     * @dev this functions is used in ConceroPool.sol
     */
    function setConceroContractSender(
        uint64 chainSelector,
        address contractAddress,
        bool isAllowed
    ) external payable onlyOwner {
        require(
            contractAddress != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );
        s_isSenderContractAllowed[chainSelector][contractAddress] = isAllowed;
    }

    /**
     * @notice Function to set the Cap of the Master pool.
     * @param newCap The new Cap of the pool
     */
    function setPoolCap(uint256 newCap) external payable onlyOwner {
        s_liquidityCap = newCap;
    }
}
