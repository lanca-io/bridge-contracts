// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILancaPool} from "./ILancaPool.sol";

interface ILancaParentPool is ILancaPool {
    /* TYPE DECLARATIONS */

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

    struct WithdrawRequest {
        address lpAddress;
        uint256 lpAmountToBurn;
        //
        uint256 totalCrossChainLiquiditySnapshot; //todo: we don't update this updateWithdrawalRequest
        uint256 amountToWithdraw;
        uint256 liquidityRequestedFromEachPool; // this may be calculated by CLF later
        uint256 remainingLiquidityFromChildPools;
        uint256 triggeredAtTimestamp;
    }

    struct DepositRequest {
        address lpAddress;
        uint256 childPoolsLiquiditySnapshot;
        uint256 usdcAmountToDeposit;
        uint256 deadline;
    }

    struct DepositOnTheWay {
        uint64 chainSelector;
        bytes32 ccipMessageId;
        uint256 amount;
    }

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

    event CLFRequestError(
        bytes32 indexed requestId,
        ILancaParentPool.CLFRequestType requestType,
        bytes err
    );
    event RetryWithdrawalPerformed(bytes32 id);
    event WithdrawUpkeepPerformed(bytes32 id);
    event WithdrawRequestUpdated(bytes32 id);
    event PendingWithdrawRequestAdded(bytes32 id);
    event WithdrawalRequestInitiated(
        bytes32 indexed requestId,
        address caller,
        uint256 triggedAtTimestamp
    );

    /* ERRORS */
    /// @notice error emitted when the CCIP message sender is not allowed.
    error SenderNotAllowed(address sender);
    error WithdrawalRequestAlreadyExists();
    error DepositAmountBelowMinimum(uint256 minAmount);
    error DepositRequestNotReady();
    error DepositsOnTheWayArrayFull();
    error WithdrawAmountBelowMinimum(uint256 minAmount);

    /// @notice error emitted when the max amount accepted by the pool is reached
    error MaxDepositCapReached(uint256 maxCap);
    error DistributeLiquidityRequestAlreadyProceeded(bytes32 requestId);
    /// @notice error emitted when the caller is not the LP who opened the request
    error NotAllowedToCompleteDeposit();
    /// @notice error emitted when the request doesn't exist
    error WithdrawRequestDoesntExist(bytes32 withdrawalId);
    error OnlyRouterCanFulfill(address);
    error Unauthorized();
    error NotUsdcToken();
    error DepositDeadlinePassed();

    error WithdrawalAlreadyTriggered(bytes32 id);
    error WithdrawalRequestDoesntExist(bytes32 id);
    error WithdrawalRequestNotReady(bytes32 id);
    error WithdrawalAlreadyPerformed(bytes32 id);

    /* FUNCTIONS */
    function getWithdrawalIdByLPAddress(address lpAddress) external view returns (bytes32);
    function startDeposit(uint256 usdcAmount) external;

    function setPools(
        uint64 chainSelector,
        address pool,
        bool isRebalancingNeeded
    ) external payable;

    function calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256);

    function calculateLPTokensToMint(
        uint256 childPoolsBalance,
        uint256 amountToDeposit
    ) external view returns (uint256);

    function setPoolCap(uint256 newCap) external payable;

    function withdrawDepositFees() external payable;

    function sendCLFRequest(bytes[] memory args) external returns (bytes32);

    function calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256);

    function fulfillRequestWrapper(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) external;

    function retryPerformWithdrawalRequest() external;
}
