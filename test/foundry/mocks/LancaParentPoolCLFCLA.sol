// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LancaPoolCommonStorage} from "contracts/pools/storages/LancaPoolCommonStorage.sol";
import {LancaParentPoolStorage} from "contracts/pools/storages/LancaParentPoolStorage.sol";

contract LancaParentPoolCLFCLAMock is LancaPoolCommonStorage, LancaParentPoolStorage {
    using SafeERC20 for IERC20;

    error InvalidCLFRequestType();

    function sendCLFRequest(bytes memory data) external returns (bytes memory) {
        return keccak256(data);
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        ILancaParentPool.CLFRequestType requestType = s_clfRequestTypes[requestId];

        require(requestType != ILancaParentPool.CLFRequestType.empty, InvalidCLFRequestType());

        delete s_clfRequestTypes[requestId];

        if (err.length > 0) {
            if (
                requestType == ILancaParentPool.CLFRequestType.startDeposit_getChildPoolsLiquidity
            ) {
                delete s_depositRequests[requestId];
            } else if (
                requestType ==
                ILancaParentPool.CLFRequestType.startWithdrawal_getChildPoolsLiquidity
            ) {
                bytes32 withdrawalId = s_withdrawalIdByCLFRequestId[requestId];
                address lpAddress = s_withdrawRequests[withdrawalId].lpAddress;
                uint256 lpAmountToBurn = s_withdrawRequests[withdrawalId].lpAmountToBurn;

                delete s_withdrawRequests[withdrawalId];
                delete s_withdrawalIdByLPAddress[lpAddress];
                delete s_withdrawalIdByCLFRequestId[requestId];

                IERC20(i_lpToken).safeTransfer(lpAddress, lpAmountToBurn);
            }

            emit CLFRequestError(requestId, requestType, err);
        } else {
            if (
                requestType == ILancaParentPool.CLFRequestType.startDeposit_getChildPoolsLiquidity
            ) {
                _handleStartDepositCLFFulfill(requestId, response);
            } else if (
                requestType ==
                ILancaParentPool.CLFRequestType.startWithdrawal_getChildPoolsLiquidity
            ) {
                _handleStartWithdrawalCLFFulfill(requestId, response);
                delete s_withdrawalIdByCLFRequestId[requestId];
            } else if (
                requestType == ILancaParentPool.CLFRequestType.withdrawal_requestLiquidityCollection
            ) {
                _handleAutomationCLFFulfill(requestId);
            } else {
                revert InvalidCLFRequestType();
            }
        }
    }

    /**
     * @notice Handles the fulfillment of a CLF request for starting a deposit
     * @param requestId the id of the request sent
     * @param response the response of the request sent
     */
    function _handleStartDepositCLFFulfill(bytes32 requestId, bytes memory response) internal {
        ILancaParentPool.DepositRequest storage request = s_depositRequests[requestId];
        (
            uint256 childPoolsLiquidity,
            bytes1[] memory depositsOnTheWayIdsToDelete
        ) = _decodeCLFResponse(response);

        request.childPoolsLiquiditySnapshot = childPoolsLiquidity;

        _deleteDepositsOnTheWayByIndexes(depositsOnTheWayIdsToDelete);
    }

    function _handleStartWithdrawalCLFFulfill(bytes32 requestId, bytes memory response) internal {
        (
            uint256 childPoolsLiquidity,
            bytes1[] memory depositsOnTheWayIdsToDelete
        ) = _decodeCLFResponse(response);

        bytes32 withdrawalId = s_withdrawalIdByCLFRequestId[requestId];
        ILancaParentPool.WithdrawRequest storage request = s_withdrawRequests[withdrawalId];

        _updateWithdrawalRequest(request, withdrawalId, childPoolsLiquidity);
        _deleteDepositsOnTheWayByIndexes(depositsOnTheWayIdsToDelete);
    }

    /**
     * @notice taken from the ConceroAutomation::fulfillRequest logic
     * @dev this function is called when a CLF request is fulfilled and the request is removed from the
     * fulfillment queue
     * @param requestId the id of the request sent
     */
    function _handleAutomationCLFFulfill(bytes32 requestId) internal {
        bytes32 withdrawalId = s_withdrawalIdByCLFRequestId[requestId];
        uint256 withdrawalRequestIdsLength = s_withdrawalRequestIds.length;
        for (uint256 i; i < withdrawalRequestIdsLength; ++i) {
            if (s_withdrawalRequestIds[i] == withdrawalId) {
                s_withdrawalRequestIds[i] = s_withdrawalRequestIds[withdrawalRequestIdsLength - 1];
                s_withdrawalRequestIds.pop();
            }
        }
    }

    function _deleteDepositsOnTheWayByIndexes(
        bytes1[] memory depositsOnTheWayIndexesToDelete
    ) internal {
        uint256 depositsOnTheWayIndexesToDeleteLength = depositsOnTheWayIndexesToDelete.length;

        if (depositsOnTheWayIndexesToDeleteLength == 0) {
            return;
        }

        uint256 s_depositsOnTheWayArrayLength = s_depositsOnTheWayArray.length;

        for (uint256 i; i < depositsOnTheWayIndexesToDeleteLength; ++i) {
            uint8 indexToDelete = uint8(depositsOnTheWayIndexesToDelete[i]);

            if (indexToDelete >= s_depositsOnTheWayArrayLength) {
                continue;
            }

            s_depositsOnTheWayAmount -= s_depositsOnTheWayArray[indexToDelete].amount;
            delete s_depositsOnTheWayArray[indexToDelete];
        }
    }

    function _addWithdrawalOnTheWayAmountById(bytes32 withdrawalId) internal {
        uint256 awaitedChildPoolsWithdrawalAmount = s_withdrawRequests[withdrawalId]
            .amountToWithdraw - s_withdrawRequests[withdrawalId].liquidityRequestedFromEachPool;

        require(awaitedChildPoolsWithdrawalAmount != 0, WithdrawalRequestDoesntExist(withdrawalId));

        s_withdrawalsOnTheWayAmount += awaitedChildPoolsWithdrawalAmount;
    }

    /**
     * @notice Sends a request to Chainlink Functions to collect liquidity from the child pools
     * @param withdrawalId the id of the withdrawal request
     * @param liquidityRequestedFromEachPool the amount of liquidity to be collected from each child pool
     * @return the id of the request
     */
    function _sendLiquidityCollectionRequest(
        bytes32 withdrawalId,
        uint256 liquidityRequestedFromEachPool
    ) internal returns (bytes32) {
        bytes[] memory args = new bytes[](5);
        args[0] = abi.encodePacked(i_collectLiquidityJsCodeHashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);
        args[2] = abi.encodePacked(
            ILancaParentPool.CLFRequestType.withdrawal_requestLiquidityCollection
        );
        args[3] = abi.encodePacked(liquidityRequestedFromEachPool);
        args[4] = abi.encodePacked(withdrawalId);

        bytes32 reqId = _sendRequest(args);
        s_withdrawalIdByCLFRequestId[reqId] = withdrawalId;
        return reqId;
    }

    /**
     * @notice Calculates the amount of USDC that can be withdrawn given the cross-chain liquidity of the parent pool
     * @param childPoolsBalance the balance of the child pools
     * @param clpAmount the amount of LP tokens to be used for withdrawal
     * @param lpSupply the total supply of LP tokens
     * @return the amount of USDC that can be withdrawn
     */
    function _calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount,
        uint256 lpSupply
    ) internal view returns (uint256) {
        uint256 parentPoolLiquidity = i_usdc.balanceOf(address(this)) +
            s_loansInUse +
            s_depositsOnTheWayAmount -
            s_depositFeeAmount;
        uint256 totalCrossChainLiquidity = childPoolsBalance + parentPoolLiquidity;

        //USDC_WITHDRAWABLE = POOL_BALANCE x (LP_INPUT_AMOUNT / TOTAL_LP)
        uint256 amountUsdcToWithdraw = (((_convertToLPTokenDecimals(totalCrossChainLiquidity) *
            clpAmount) * PRECISION_HANDLER) / lpSupply) / PRECISION_HANDLER;

        return _convertToUSDCTokenDecimals(amountUsdcToWithdraw);
    }
}
