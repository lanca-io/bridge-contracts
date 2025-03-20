// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaParentPool} from "contracts/pools/LancaParentPool.sol";
import {ILancaParentPool} from "contracts/pools/interfaces/ILancaParentPool.sol";
import {LPToken} from "contracts/pools/LPToken.sol";

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

    function exposed_setClfReqTypeById(
        bytes32 clfReqId,
        ILancaParentPool.ClfRequestType clfReqType
    ) external {
        s_clfRequestTypes[clfReqId] = clfReqType;
    }

    function exposed_setWithdrawalIdByClfId(bytes32 clfReqId, bytes32 withdrawalId) external {
        s_withdrawalIdByCLFRequestId[clfReqId] = withdrawalId;
    }

    function exposed_setWithdrawalReqById(
        bytes32 withdrawalId,
        ILancaParentPool.WithdrawRequest memory withdrawalReq
    ) external {
        s_withdrawRequests[withdrawalId] = withdrawalReq;
    }

    function exposed_setDepositFeeAmount(uint256 amount) external {
        s_depositFeeAmount = amount;
    }

    function exposed_setDstPoolByChainSelector(uint64 chainSelector, address pool) external {
        s_dstPoolByChainSelector[chainSelector] = pool;
    }

    function exposed_setWithdrawRequests(bytes32 withdrawalId, ILancaParentPool.WithdrawRequest memory request) external {
        s_withdrawRequests[withdrawalId] = request;
    }

    function exposed_setLiquidityCap(uint256 cap) external {
        s_liquidityCap = cap;
    }

    /* GETTERS */
    function exposed_getLpToken() external view returns (address) {
        return address(i_lpToken);
    }

    function exposed_getILpToken() external view returns (LPToken) {
        return i_lpToken;
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

    function exposed_getMessengers() external view returns (address[3] memory) {
        address[3] memory messengers = [i_messenger0, i_messenger1, i_messenger2];
        return messengers;
    }

    function exposed_getAutomationForwarder() public view returns (address) {
        return i_automationForwarder;
    }
}
