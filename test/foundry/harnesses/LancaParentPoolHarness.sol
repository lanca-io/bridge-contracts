// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaParentPool} from "contracts/pools/LancaParentPool.sol";
import {ILancaParentPool} from "contracts/pools/interfaces/ILancaParentPool.sol";

contract LancaParentPoolHarness is LancaParentPool {
    constructor(
        TokenConfig memory tokenConfig,
        AddressConfig memory addressConfig,
        HashConfig memory hashConfig,
        PoolConfig memory poolConfig
    ) LancaParentPool(tokenConfig, addressConfig, hashConfig, poolConfig) {}

    function exposed_setWithdrawAmountLocked(uint256 newWithdrawAmountLocked) external {
        s_withdrawAmountLocked = newWithdrawAmountLocked;
    }

    function exposed_setChildPoolsLiqSnapshotByDepositId(
        bytes32 depositId,
        uint256 liqSnapshot
    ) external {
        s_depositRequests[depositId].childPoolsLiquiditySnapshot = liqSnapshot;
    }

    function exposed_setDistributeLiquidityRequestProcessed(
        bytes32 requestId,
        bool processed
    ) external {
        s_distributeLiquidityRequestProcessed[requestId] = processed;
    }

    function exposed_setDstPoolByChainSelector(uint64 chainSelector, address pool) external {
        s_dstPoolByChainSelector[chainSelector] = pool;
    }

    function exposed_setClfReqTypeById(
        bytes32 clfReqId,
        ILancaParentPool.ClfRequestType clfReqType
    ) external {
        s_clfRequestTypes[clfReqId] = clfReqType;
    }

    function exposed_setWithdrawalIdByClfRequestId(
        bytes32 clfReqId,
        bytes32 withdrawalId
    ) external {
        s_withdrawalIdByCLFRequestId[clfReqId] = withdrawalId;
    }

    function exposed_setWithdrawalRequestIds(bytes32[] memory withdrawalRequestIds) public {
        s_withdrawalRequestIds = withdrawalRequestIds;
    }

    function exposed_setWithdrawalReqById(
        bytes32 withdrawalId,
        ILancaParentPool.WithdrawRequest memory withdrawalReq
    ) external {
        s_withdrawRequests[withdrawalId] = withdrawalReq;
    }

    function exposed_setDepositFeesSum(uint256 depositFeesSum) external {
        s_depositFeesSum = depositFeesSum;
    }

    function exposed_setWithdrawTriggered(bytes32 withdrawalId, bool triggered) external {
        s_withdrawTriggered[withdrawalId] = triggered;
    }

    /* GETTERS */
    function exposed_getWithdrawalsOnTheWayAmount() external view returns (uint256) {
        return s_withdrawalsOnTheWayAmount;
    }

    function exposed_getWithdrawalIdByCLFRequestId(
        bytes32 clfReqId
    ) external view returns (bytes32) {
        return s_withdrawalIdByCLFRequestId[clfReqId];
    }

    function exposed_getClfRequestTypeById(
        bytes32 clfReqId
    ) external view returns (ILancaParentPool.ClfRequestType) {
        return s_clfRequestTypes[clfReqId];
    }

    function exposed_getLpToken() external view returns (address) {
        return address(i_lpToken);
    }

    function exposed_getPoolChainSelectors() external view returns (uint64[] memory) {
        return s_poolChainSelectors;
    }

    function exposed_getDstPoolByChainSelector(
        uint64 chainSelector
    ) external view returns (address) {
        return s_dstPoolByChainSelector[chainSelector];
    }

    function exposed_getClfRouter() public view returns (address) {
        return address(i_clfRouter);
    }

    function exposed_getDepositFeesSum() public view returns (uint256) {
        return s_depositFeesSum;
    }

    function exposed_getDepositFeeAmount() public view returns (uint256) {
        return i_depositFeeAmount;
    }

    function exposed_getMessengers() public view returns (address[3] memory) {
        address[3] memory messengers = [i_messenger0, i_messenger1, i_messenger2];
        return messengers;
    }

    function exposed_getDistributeLiquidityRequestProcessed(
        bytes32 requestId
    ) public view returns (bool) {
        return s_distributeLiquidityRequestProcessed[requestId];
    }

    function exposed_getAutomationForwarder() public view returns (address) {
        return i_automationForwarder;
    }
}
