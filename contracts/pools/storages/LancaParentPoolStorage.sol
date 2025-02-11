// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILancaParentPool} from "../interfaces/ILancaParentPool.sol";

abstract contract LancaParentPoolStorage {
    /* STATE VARIABLES */

    uint256 internal s_liquidityCap;

    uint256 internal s_withdrawAmountLocked;

    uint256 internal s_depositsOnTheWayAmount;

    uint256 internal s_depositFeesSum;

    uint256 internal s_withdrawalsOnTheWayAmount;

    uint8 internal s_latestDepositOnTheWayIndex;

    //    bytes32 internal s_getChildPoolsLiquidityJsCodeHashSum;

    //    bytes32 internal s_ethersHashSum;

    /* ARRAYS */

    ILancaParentPool.DepositOnTheWay[150] internal s_depositsOnTheWayArray;

    bytes32[] internal s_withdrawalRequestIds;

    /* MAPPINGS */

    //    mapping(uint64 chainSelector => address pool) internal s_dstPoolByChainSelector;

    mapping(bytes32 clfReqId => ILancaParentPool.ClfRequestType) internal s_clfRequestTypes;

    mapping(bytes32 clfReqId => ILancaParentPool.DepositRequest) internal s_depositRequests;

    mapping(address lpAddress => bytes32 withdrawalId) internal s_withdrawalIdByLPAddress;

    mapping(bytes32 clfReqId => bytes32 withdrawalId) internal s_withdrawalIdByCLFRequestId;

    mapping(bytes32 withdrawalId => ILancaParentPool.WithdrawRequest) internal s_withdrawRequests;

    mapping(bytes32 withdrawalId => bool isTriggered) internal s_withdrawTriggered;

    /* STORAGE GAP */
    /// @notice gap to reserve storage in the contract for future variable additions
    uint256[50] private __gap;

    /* GETTERS */

    function getWithdrawalIdByLPAddress(address lpAddress) external view returns (bytes32) {
        return s_withdrawalIdByLPAddress[lpAddress];
    }

    function getWithdrawalsOnTheWayAmount() external view returns (uint256) {
        return s_withdrawalsOnTheWayAmount;
    }

    function getPendingWithdrawalRequestIds() external view returns (bytes32[] memory) {
        return s_withdrawalRequestIds;
    }

    function getLiquidityCap() external view returns (uint256) {
        return s_liquidityCap;
    }

    function getDepositRequestById(
        bytes32 clfReqId
    ) external view returns (ILancaParentPool.DepositRequest memory) {
        return s_depositRequests[clfReqId];
    }

    function getClfReqTypeById(
        bytes32 clfReqId
    ) external view returns (ILancaParentPool.ClfRequestType) {
        return s_clfRequestTypes[clfReqId];
    }

    function getWithdrawalRequestById(
        bytes32 withdrawalId
    ) external view returns (ILancaParentPool.WithdrawRequest memory) {
        return s_withdrawRequests[withdrawalId];
    }
}
