// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILancaPool} from "./ILancaPool.sol";

interface ILancaParentPool is ILancaPool {
    /* TYPE DECLARATIONS */

    /// @notice Enum to specify the type of liquidity redistribution
    enum RedistributeLiquidityType {
        addPool,
        removePool
    }

    /// @notice Struct to track Functions Requests Type
    enum CLFRequestType {
        startDeposit_getChildPoolsLiquidity,
        startWithdrawal_getChildPoolsLiquidity,
        withdrawal_requestLiquidityCollection,
        liquidityRedistribution
    }

    /// @notice `ccipSend` to distribute liquidity
    struct Pools {
        uint64 chainSelector;
        address poolAddress;
    }

    /// @notice Struct to track withdrawal requests
    /// @dev Contains the LP's address, the amount of LP tokens to burn,
    /// the snapshot of the total cross-chain liquidity, the amount of USDC to withdraw,
    /// the amount of USDC requested from each child pool, the remaining amount to receive
    /// and the timestamp when the withdrawal request was triggered
    struct WithdrawRequest {
        address lpAddress;
        uint256 lpAmountToBurn;
        uint256 totalCrossChainLiquiditySnapshot; //todo: we don't update this updateWithdrawalRequest
        uint256 amountToWithdraw;
        uint256 liquidityRequestedFromEachPool; // this may be calculated by CLF later
        uint256 remainingLiquidityFromChildPools;
        uint256 triggeredAtTimestamp;
    }

    /// @notice Struct to track deposit requests
    /// @dev Contains the LP's address, the snapshot of the child pools' liquidity,
    /// the amount of USDC the LP wants to deposit and the deadline to complete the deposit
    struct DepositRequest {
        address lpAddress;
        uint256 childPoolsLiquiditySnapshot;
        uint256 usdcAmountToDeposit;
        uint256 deadline;
    }

    /// @notice Struct to track deposits on the way
    /// @dev Contains the chain selector, the CCIP message ID, and the amount of the deposit
    struct DepositOnTheWay {
        uint64 chainSelector;
        bytes32 ccipMessageId;
        uint256 amount;
    }

    /// @notice Struct to track perform withdrawal requests
    /// @dev Contains the LP's address, the amount of the withdrawal, the ID of the withdrawal
    /// and a flag to indicate if the withdrawal failed
    struct PerformWithdrawRequest {
        address lpAddress;
        uint256 amount;
        bytes32 withdrawId;
        bool failed;
    }

    /* EVENTS */

    event FailedExecutionLayerTxSettled(bytes32 indexed conceroMessageId);

    /// @notice Event emitted when a value is withdrawn from the contract.
    event WithdrawalCompleted(
        bytes32 indexed requestId,
        address indexed lpAddress,
        address token,
        uint256 amount
    );

    /// @notice Event emitted when a cross-chain transaction is received.
    event CCIPReceived(
        bytes32 indexed ccipMessageId,
        uint64 srcChainSelector,
        address sender,
        address token,
        uint256 amount
    );

    /// @notice Event emitted when a cross-chain message is sent.
    event CCIPSent(
        bytes32 indexed messageId,
        uint64 destinationChainSelector,
        address receiver,
        uint256 amount
    );

    /// @notice Event emitted in depositLiquidity when a deposit is successfully executed.
    event DepositInitiated(
        bytes32 indexed requestId,
        address indexed lpAddress,
        uint256 amount,
        uint256 deadline
    );

    /// @notice Event emitted when a deposit is completed.
    event DepositCompleted(
        bytes32 indexed requestId,
        address indexed lpAddress,
        uint256 amount,
        uint256 lpTokensToMint
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

    /// @notice Emitted when a withdrawal request is initiated.
    /// @param requestId The id of the request.
    /// @param caller The address that initiated the request.
    /// @param triggedAtTimestamp The timestamp at which the request was initiated.
    event WithdrawalRequestInitiated(
        bytes32 indexed requestId,
        address caller,
        uint256 triggedAtTimestamp
    );

    /* ERRORS */
    /// @notice error emitted when the sender is not allowed
    /// @param sender the sender of the message
    error SenderNotAllowed(address sender);

    /// @notice error emitted when a withdrawal request with the same id already exists
    error WithdrawalRequestAlreadyExists();

    /// @notice error emitted when the deposit amount is below the minimum
    /// @param minAmount the minimum deposit amount
    error DepositAmountBelowMinimum(uint256 minAmount);

    /// @notice error emitted when the deposit request is not ready to be processed
    error DepositRequestNotReady();

    /// @notice error emitted when the deposits on the way array is full
    error DepositsOnTheWayArrayFull();

    /// @notice error emitted when the withdraw amount is below the minimum
    /// @param minAmount the minimum withdraw amount
    error WithdrawAmountBelowMinimum(uint256 minAmount);

    /// @notice error emitted when the max amount accepted by the pool is reached
    error MaxDepositCapReached(uint256 maxCap);

    /// @notice error emitted when a distribute liquidity request with the same id already exists
    /// @param requestId the id of the request
    error DistributeLiquidityRequestAlreadyProceeded(bytes32 requestId);

    /// @notice error emitted when the caller is not the LP who opened the request
    error NotAllowedToCompleteDeposit();

    /// @notice error emitted when the request doesn't exist
    error WithdrawRequestDoesntExist(bytes32 withdrawalId);

    /// @notice Error emitted when the caller is unauthorized
    error Unauthorized();

    /// @notice Error emitted when the token is not USDC
    error NotUsdcToken();

    /// @notice Error emitted when the deposit deadline has passed
    error DepositDeadlinePassed();

    /// @notice Error emitted when a withdrawal has already been triggered
    /// @param id The ID of the withdrawal
    error WithdrawalAlreadyTriggered(bytes32 id);

    /// @notice Error emitted when a withdrawal request does not exist
    /// @param id The ID of the withdrawal request
    error WithdrawalRequestDoesntExist(bytes32 id);

    /// @notice Error emitted when a withdrawal request is not yet ready
    /// @param id The ID of the withdrawal request
    error WithdrawalRequestNotReady(bytes32 id);

    /// @notice Error emitted when a withdrawal has already been performed
    /// @param id The ID of the withdrawal
    error WithdrawalAlreadyPerformed(bytes32 id);

    /* FUNCTIONS */


    /**
     * @notice starts a deposit request for the given amount of USDC
     * @param usdcAmount the amount of USDC to deposit
     */
    function startDeposit(uint256 usdcAmount) external;

    /**
     * @notice sets the pool address and the rebalancing status for the given chain selector
     * @param chainSelector the chain selector
     * @param pool the pool address
     * @param isRebalancingNeeded whether rebalancing is needed
     */
    function setPools(
        uint64 chainSelector,
        address pool,
        bool isRebalancingNeeded
    ) external payable;

    /**
     * @notice calculates the withdrawable amount for the given child pool balance and CLP amount
     * @param childPoolsBalance the balance of the child pools
     * @param clpAmount the amount of CLP to withdraw
     * @return the withdrawable amount
     */
    function calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256);

    /**
     * @notice calculates the amount of LP tokens to mint for the given child pool balance and deposit amount
     * @param childPoolsBalance the balance of the child pools
     * @param amountToDeposit the amount of USDC to deposit
     * @return the amount of LP tokens to mint
     */
    function calculateLPTokensToMint(
        uint256 childPoolsBalance,
        uint256 amountToDeposit
    ) external view returns (uint256);

    /**
     * @notice sets the pool cap to the given value
     * @param newCap the new pool cap
     */
    function setPoolCap(uint256 newCap) external payable;

    /**
     * @notice withdraws the deposit fees
     */
    function withdrawDepositFees() external payable;

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
}
