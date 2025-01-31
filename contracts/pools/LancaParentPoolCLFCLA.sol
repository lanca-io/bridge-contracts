// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
//import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
//import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILancaParentPoolCLFCLA} from "./interfaces/ILancaParentPoolCLFCLA.sol";
import {ILancaParentPool} from "./interfaces/ILancaParentPool.sol";
import {LibErrors} from "../common/libraries/LibErrors.sol";
import {LancaParentPoolStorage} from "./storages/LancaParentPoolStorage.sol";
import {LancaParentPoolCommon} from "./LancaParentPoolCommon.sol";

contract LancaParentPoolCLFCLA is
    ILancaParentPoolCLFCLA,
    /*FunctionsClient,*/
    AutomationCompatible,
    LancaParentPoolCommon,
    LancaParentPoolStorage
{
    using SafeERC20 for IERC20;
    //using FunctionsRequest for FunctionsRequest.Request;

    /* TYPES */
    /* CONSTANT VARIABLES */
    uint256 internal constant CCIP_ESTIMATED_TIME_TO_COMPLETE = 30 minutes;
    //uint32 internal constant CLF_CALLBACK_GAS_LIMIT = 2_000_000;
    // string internal constant JS_CODE =
    //     "try{const [b,o,f]=bytesArgs;const m='https://raw.githubusercontent.com/';const u=m+'ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js';const q=m+'concero/contracts-v1/'+'release'+`/tasks/CLFScripts/dist/pool/${f==='0x02' ? 'withdrawalLiquidityCollection':f==='0x03' ? 'redistributePoolsLiquidity':'getChildPoolsLiquidity'}.min.js`;const [t,p]=await Promise.all([fetch(u),fetch(q)]);const [e,c]=await Promise.all([t.text(),p.text()]);const g=async s=>{return('0x'+Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s)))).map(v=>('0'+v.toString(16)).slice(-2).toLowerCase()).join(''));};const r=await g(c);const x=await g(e);if(r===b.toLowerCase()&& x===o.toLowerCase()){const ethers=new Function(e+';return ethers;')();return await eval(c);}throw new Error(`${r}!=${b}||${x}!=${o}`);}catch(e){throw new Error(e.message.slice(0,255));}";

    /* IMMUTABLE VARIABLES */
    // bytes32 private immutable i_clfDonId;
    // uint64 private immutable i_clfSubId;
    // uint8 internal immutable i_donHostedSecretsSlotId;
    // uint64 internal immutable i_donHostedSecretsVersion;
    // bytes32 internal immutable i_collectLiquidityJsCodeHashSum;

    constructor(
        address parentPoolProxy,
        address lpToken,
        address usdc,
        address lancaBridge,
        // address clfRouter,
        // uint64 clfSubId,
        // bytes32 clfDonId,
        // uint8 donHostedSecretsSlotId,
        // uint64 donHostedSecretsVersion,
        // bytes32 collectLiquidityJsCodeHashSum,
        // address[3] memory messengers
    )
        LancaParentPoolCommon(parentPoolProxy, lpToken, usdc, lancaBridge/*, messengers*/)
        /* FunctionsClient(clfRouter)*/
    {
        // i_clfSubId = clfSubId;
        // i_clfDonId = clfDonId;
        // i_donHostedSecretsSlotId = donHostedSecretsSlotId;
        // i_donHostedSecretsVersion = donHostedSecretsVersion;
    }

    /* EXTERNAL FUNCTIONS */

    /**
     * @notice sends a request to Chainlink Functions
     * @param args the arguments for the request as bytes array
     * @return the request ID
     */
    // function sendCLFRequest(bytes[] memory args) external returns (bytes32) {
    //     return _sendRequest(args);
    // }


    /**
     * @notice Allows the LP to retry the withdrawal request if the Chainlink Functions failed to execute it
     */
    function retryPerformWithdrawalRequest() external {
        bytes32 withdrawalId = s_withdrawalIdByLPAddress[msg.sender];

        require(
            msg.sender == s_withdrawRequests[withdrawalId].lpAddress,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.unauthorized)
        );

        uint256 liquidityRequestedFromEachPool = s_withdrawRequests[withdrawalId]
            .liquidityRequestedFromEachPool;

        require(liquidityRequestedFromEachPool != 0, WithdrawalRequestDoesntExist(withdrawalId));

        /// @dev why 10 ?
        require(
            s_withdrawRequests[withdrawalId].remainingLiquidityFromChildPools >= 10,
            WithdrawalAlreadyPerformed(withdrawalId)
        );

        require(
            block.timestamp >=
                s_withdrawRequests[withdrawalId].triggeredAtTimestamp +
                    CCIP_ESTIMATED_TIME_TO_COMPLETE,
            WithdrawalRequestNotReady(withdrawalId)
        );

        bytes32 reqId = _sendLiquidityCollectionRequest(
            withdrawalId,
            liquidityRequestedFromEachPool
        );

        emit RetryWithdrawalPerformed(reqId);
    }

    function calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256) {
        return _calculateWithdrawableAmount(childPoolsBalance, clpAmount, i_lpToken.totalSupply());
    }

    function fulfillRequestWrapper(
        bytes32 requestId,
        bytes memory delegateCallResponse,
        bytes memory err
    ) external {
        //require(msg.sender == i_clfRouter, OnlyRouterCanFulfill());
        fulfillRequest(requestId, delegateCallResponse, err);
    }

    /* AUTOMATION EXTERNAL */

    /**
     * @notice Chainlink Automation Function to check for requests with fulfilled conditions
     * We don't use the calldata
     * @return upkeepNeeded it will return true, if the time condition is reached
     * @return performData the payload we need to send through performUpkeep to Chainlink functions.
     * @dev this function must only be simulated offchain by Chainlink Automation nodes
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override cannotExecute returns (bool, bytes memory) {
        uint256 s_withdrawalRequestIdsLength = s_withdrawalRequestIds.length;
        for (uint256 i; i < s_withdrawalRequestIdsLength; ++i) {
            bytes32 withdrawalId = s_withdrawalRequestIds[i];

            if (s_withdrawRequests[withdrawalId].amountToWithdraw == 0) {
                continue;
            }

            if (
                !s_withdrawTriggered[withdrawalId] &&
                block.timestamp > s_withdrawRequests[withdrawalId].triggeredAtTimestamp
            ) {
                bytes memory performData = abi.encode(withdrawalId);
                return (true, performData);
            }
        }
        return (false, "");
    }

    /**
     * @notice Chainlink Automation function that will perform storage update and call Chainlink Functions
     * @param performData the performData encoded in checkUpkeep function
     * @dev this function must be called only by the Chainlink Forwarder unique address
     */
    function performUpkeep(bytes calldata performData) external override {
        bytes32 withdrawalId = abi.decode(performData, (bytes32));

        require(withdrawalId != bytes32(0), WithdrawalRequestDoesntExist(withdrawalId));
        require(
            block.timestamp >= s_withdrawRequests[withdrawalId].triggeredAtTimestamp,
            WithdrawalRequestNotReady(withdrawalId)
        );
        require(!s_withdrawTriggered[withdrawalId], WithdrawalAlreadyTriggered(withdrawalId));

        s_withdrawTriggered[withdrawalId] = true;

        uint256 liquidityRequestedFromEachPool = s_withdrawRequests[withdrawalId]
            .liquidityRequestedFromEachPool;

        require(liquidityRequestedFromEachPool != 0, WithdrawalRequestDoesntExist(withdrawalId));

        bytes32 reqId = _sendLiquidityCollectionRequest(
            withdrawalId,
            liquidityRequestedFromEachPool
        );

        s_clfRequestTypes[reqId] = ILancaParentPool
            .CLFRequestType
            .withdrawal_requestLiquidityCollection;
        _addWithdrawalOnTheWayAmountById(withdrawalId);
        emit WithdrawUpkeepPerformed(reqId);
    }

    /* INTERNAL FUNCTIONS */
    /**
     * @notice Chainlink Functions fallback function
     * @param requestId the ID of the request sent
     * @param response the response of the request sent
     * @param err the error of the request sent
     * @dev response & err will never be empty or populated at same time.
     */
    // solhint-disable-next-line chainlink-solidity/prefix-internal-functions-with-underscore
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

    /**
     * @notice Handles the fulfillment of a CLF request for starting a withdrawal
     * @param requestId the id of the request sent
     * @param response the response of the request sent
     */
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

    /**
     * @notice Deletes deposits on the way by their specified indexes.
     * @param depositsOnTheWayIndexesToDelete Array of indexes indicating which deposits to delete.
     */
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

    /**
     * @notice Function to send a Request to Chainlink Functions
     * @param args the arguments for the request as bytes array
     */
    // function _sendRequest(bytes[] memory args) internal returns (bytes32) {
    //     FunctionsRequest.Request memory req;
    //     req.initializeRequestForInlineJavaScript(JS_CODE);
    //     req.addDONHostedSecrets(i_donHostedSecretsSlotId, i_donHostedSecretsVersion);
    //     req.setBytesArgs(args);

    //     return _sendRequest(req.encodeCBOR(), i_clfSubId, CLF_CALLBACK_GAS_LIMIT, i_clfDonId);
    // }

    /**
     * @notice adds the amount of a withdrawal request on the way to the total sum
     * @param withdrawalId the id of the withdrawal request
     */
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

    /**
     * @notice decodes the response of a CLF request
     * @param response the response of the request sent
     * @return the total balance of the child pools
     * @return the ids of the deposits to be deleted
     */
    function _decodeCLFResponse(
        bytes memory response
    ) internal pure returns (uint256, bytes1[] memory) {
        uint256 totalBalance;
        assembly {
            totalBalance := mload(add(response, 32))
        }

        if (response.length == 32) {
            return (totalBalance, new bytes1[](0));
        } else {
            bytes1[] memory depositsOnTheWayIdsToDelete = new bytes1[](response.length - 32);
            for (uint256 i = 32; i < response.length; ++i) {
                depositsOnTheWayIdsToDelete[i - 32] = response[i];
            }

            return (totalBalance, depositsOnTheWayIdsToDelete);
        }
    }

    /* PRIVATE FUNCTIONS */

    /**
     * @notice Function to update cross-chain rewards which will be paid to liquidity providers in the end of
     * withdraw period.
     * @param withdrawalId - pointer to the WithdrawRequest struct
     * @param childPoolsLiquidity The total liquidity of all child pools
     * @dev This function must be called only by an allowed Messenger & must not revert
     * @dev _totalUSDCCrossChainBalance MUST have 10**6 decimals.
     */
    function _updateWithdrawalRequest(
        ILancaParentPool.WithdrawRequest storage withdrawalRequest,
        bytes32 withdrawalId,
        uint256 childPoolsLiquidity
    ) private {
        uint256 lpToBurn = withdrawalRequest.lpAmountToBurn;
        uint256 childPoolsCount = s_poolChainSelectors.length;

        uint256 amountToWithdrawWithUsdcDecimals = _calculateWithdrawableAmount(
            childPoolsLiquidity,
            lpToBurn,
            i_lpToken.totalSupply()
        );
        uint256 withdrawalPortionPerPool = amountToWithdrawWithUsdcDecimals / (childPoolsCount + 1);

        withdrawalRequest.amountToWithdraw = amountToWithdrawWithUsdcDecimals;
        withdrawalRequest.liquidityRequestedFromEachPool = withdrawalPortionPerPool;
        withdrawalRequest.remainingLiquidityFromChildPools =
            amountToWithdrawWithUsdcDecimals -
            withdrawalPortionPerPool;
        uint256 triggeredAtTimestamp = block.timestamp + WITHDRAWAL_COOLDOWN_SECONDS;
        withdrawalRequest.triggeredAtTimestamp = triggeredAtTimestamp;

        s_withdrawalRequestIds.push(withdrawalId);
        emit WithdrawalRequestInitiated(
            withdrawalId,
            withdrawalRequest.lpAddress,
            triggeredAtTimestamp
        );
    }
}
