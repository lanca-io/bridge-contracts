// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILancaParentPool} from "../interfaces/ILancaParentPool.sol";

abstract contract LancaParentPoolStorage {
    /* STATE VARIABLES */

    uint256 internal s_liquidityCap;

    uint256 internal s_loansInUse;

    uint8 private s_donHostedSecretsSlotId_DEPRECATED;

    uint64 private s_donHostedSecretsVersion_DEPRECATED;

    bytes32 private s_getChildPoolsLiquidityJsCodeHashSum_DEPRECATED;

    bytes32 private s_ethersHashSum_DEPRECATED;

    uint256 internal s_depositsOnTheWayAmount;

    uint8 internal s_latestDepositOnTheWayIndex;

    uint256 internal s_depositFeeAmount;

    uint256 internal s_withdrawAmountLocked;

    uint256 internal s_withdrawalsOnTheWayAmount;

    uint256[50] private __gap;

    /* ARRAYS */

    uint64[] internal s_poolChainSelectors;

    ILancaParentPool.DepositOnTheWay_DEPRECATED[] internal s_depositsOnTheWayArray_DEPRECATED;

    /* MAPPINGS */

    mapping(uint64 chainSelector => address pool) internal s_dstPoolByChainSelector;

    mapping(uint64 chainSelector => mapping(address poolAddress => bool))
        private s_isSenderContractAllowed_DEPRECATED;

    mapping(bytes32 => bool) internal s_distributeLiquidityRequestProcessed;

    mapping(bytes32 clfReqId => ILancaParentPool.ClfRequestType) internal s_clfRequestTypes;

    mapping(bytes32 clfReqId => ILancaParentPool.DepositRequest) internal s_depositRequests;

    mapping(address lpAddress => bytes32 withdrawalId) internal s_withdrawalIdByLPAddress;

    mapping(bytes32 clfReqId => bytes32 withdrawalId) internal s_withdrawalIdByCLFRequestId;

    mapping(bytes32 withdrawalId => ILancaParentPool.WithdrawRequest) internal s_withdrawRequests;

    ILancaParentPool.DepositOnTheWay[150] internal s_depositsOnTheWayArray;

    bytes32 private s_collectLiquidityJsCodeHashSum_DEPRECATED;
    bytes32 private s_distributeLiquidityJsCodeHashSum_DEPRECATED;

    bytes32[] internal s_withdrawalRequestIds;

    mapping(bytes32 withdrawalId => bool isTriggered) internal s_withdrawTriggered;

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

    /**
     * @notice Getter function to get the deposits on the way.
     * @return the array of deposits on the way
     */
    function getDepositsOnTheWay()
        external
        view
        returns (ILancaParentPool.DepositOnTheWay[150] memory)
    {
        return s_depositsOnTheWayArray;
    }
}
