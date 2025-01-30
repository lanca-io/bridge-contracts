// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaPoolStorage} from "./LancaPoolStorage.sol";

abstract contract LancaChildPoolStorage is LancaPoolStorage {
    /* MAPPINGS & ARRAYS */

    ///@notice Mapping to keep track of valid pools to transfer in case of liquidation or rebalance
    mapping(uint64 chainSelector => address pool) public s_dstPoolByChainSelector;
    //@notice Prevents CLF from triggering the same withdrawal request more than once
    mapping(bytes32 withdrawalId => bool isTriggered) public s_isWithdrawalRequestTriggered;

    ///@notice gap to reserve storage in the contract for future variable additions
    uint256[50] __gap;
}
