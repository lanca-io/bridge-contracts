// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILancaParentPool} from "../interfaces/ILancaParentPool.sol";
import {LancaPoolCommon} from "../LancaPoolCommon.sol";

abstract contract LancaParentPoolStorage is LancaPoolCommon {
    constructor(address usdc, address lancaBridge) LancaPoolCommon(usdc, lancaBridge) {}

    /* STATE VARIABLES */

    uint256 public s_liquidityCap;

    uint256 public s_withdrawAmountLocked;

    uint256 public s_depositsOnTheWayAmount;

    uint256 internal s_depositFeeAmount;

    uint256 internal s_withdrawalsOnTheWayAmount;

    uint8 internal s_latestDepositOnTheWayIndex;

    bytes32 internal s_getChildPoolsLiquidityJsCodeHashSum;

    bytes32 internal s_ethersHashSum;

    /* ARRAYS */

    ILancaParentPool.DepositOnTheWay[150] internal s_depositsOnTheWayArray;

    bytes32[] public s_withdrawalRequestIds;

    /* MAPPINGS */

    mapping(uint64 chainSelector => address pool) public s_childPools;

    mapping(bytes32 clfReqId => ILancaParentPool.CLFRequestType) public s_clfRequestTypes;

    mapping(bytes32 clfReqId => ILancaParentPool.DepositRequest) public s_depositRequests;

    mapping(address lpAddress => bytes32 withdrawalId) public s_withdrawalIdByLPAddress;

    mapping(bytes32 clfReqId => bytes32 withdrawalId) public s_withdrawalIdByCLFRequestId;

    mapping(bytes32 withdrawalId => ILancaParentPool.WithdrawRequest) public s_withdrawRequests;

    mapping(bytes32 withdrawalId => bool isTriggered) public s_withdrawTriggered;

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
}
