// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaPoolCommon} from "../LancaPoolCommon.sol";

abstract contract LancaChildPoolStorage is LancaPoolCommon {
    /// @notice Mapping to keep track of valid pools to transfer in case of liquidation or rebalance
    mapping(uint64 chainSelector => address pool) internal s_dstPoolByChainSelector;
    // @notice Prevents CLF from triggering the same withdrawal request more than once
    mapping(bytes32 withdrawalId => bool isTriggered) internal s_isWithdrawalRequestTriggered;

    /// @notice gap to reserve storage in the contract for future variable additions
    uint256[50] private __gap;
}
