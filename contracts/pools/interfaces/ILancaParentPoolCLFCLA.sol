// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILancaParentPool} from "./ILancaParentPool.sol";

interface ILancaParentPoolCLFCLA {
    /* EVENTS */

    /// @notice Emitted when a withdrawal request is initiated.
    /// @param requestId The id of the request.
    /// @param caller The address that initiated the request.
    /// @param triggedAtTimestamp The timestamp at which the request was initiated.
    event WithdrawalRequestInitiated(
        bytes32 indexed requestId,
        address caller,
        uint256 triggedAtTimestamp
    );

    /// @notice Emitted when a Cross-chain Functions request fails.
    /// @param requestId The id of the request sent.
    /// @param requestType The type of the request.
    /// @param err The error returned by the request.
    event CLFRequestError(
        bytes32 indexed requestId,
        ILancaParentPool.CLFRequestType requestType,
        bytes err
    );

    /// @notice Emitted when a retry is performed for a withdrawal.
    /// @param id The id of the retry.
    event RetryWithdrawalPerformed(bytes32 id);

    /// @notice Emitted when a withdrawal upkeep is performed.
    /// @param id The id of the upkeep.
    event WithdrawUpkeepPerformed(bytes32 id);

    /// @notice Emitted when a withdrawal request is updated.
    /// @param id The id of the request.
    event WithdrawRequestUpdated(bytes32 id);

    /// @notice Emitted when a new withdrawal request is added to the queue.
    /// @param id The id of the request.
    event PendingWithdrawRequestAdded(bytes32 id);

    /* ERRORS */

    /// @notice Error emitted when a withdrawal request does not exist
    /// @param id The ID of the withdrawal request
    error WithdrawalRequestDoesntExist(bytes32 id);

    /// @notice Error emitted when a withdrawal request is not yet ready
    /// @param id The ID of the withdrawal request
    error WithdrawalRequestNotReady(bytes32 id);

    /// @notice Error emitted when a withdrawal has already been performed
    /// @param id The ID of the withdrawal
    error WithdrawalAlreadyPerformed(bytes32 id);

    /// @notice Error emitted when the type of a Cross-chain Functions request is invalid
    error InvalidCLFRequestType();

    /* FUNCTIONS */

    function sendCLFRequest(bytes[] memory args) external returns (bytes32);

    /**
     * @notice wrapper function for fulfillRequest, to allow the router to call it
     * @param requestId the ID of the request
     * @param response the response from Chainlink Functions
     * @param err the error from Chainlink Functions
     */
    function fulfillRequestWrapper(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) external;

    /**
     * @notice retries to perform the withdrawal request
     */
    function retryPerformWithdrawalRequest() external;

    function calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256);
}

interface ILancaParentPoolCLFCLAViewDelegate {
    function calculateWithdrawableAmountViaDelegateCall(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256);

    function checkUpkeepViaDelegate() external view returns (bool, bytes memory);
}
