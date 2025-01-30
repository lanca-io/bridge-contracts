// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaChildPoolStorage} from "../storages/LancaChildPoolStorage.sol";
import {LancaOwnable} from "../LancaOwnable.sol";
import {ILancaChildPool} from "../interfaces/pools/ILancaChildPool.sol";
import {ZERO_ADDRESS} from "../Constants.sol";
import {LibErrors} from "../libraries/LibErrors.sol";

abstract contract LancaChildPoolStorageSetters is
    LancaChildPoolStorage,
    ILancaChildPool,
    LancaOwnable
{
    constructor(address owner) LancaOwnable(owner) {}

    /* EXTERNAL FUNCTIONS */
    /**
     * @notice function to manage the Cross-chain ConceroPool contracts
     * @param chainSelector chain identifications
     * @param pool address of the Cross-chain ConceroPool contract
     * @dev only owner can call it
     * @dev it's payable to save some gas.
     */
    function setPools(uint64 chainSelector, address pool) external payable onlyOwner {
        require(
            s_dstPoolByChainSelector[chainSelector] != pool && pool != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );

        s_poolChainSelectors.push(chainSelector);
        s_dstPoolByChainSelector[chainSelector] = pool;
    }

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
}
