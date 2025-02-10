// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILancaPool} from "./ILancaPool.sol";

interface ILancaParentPool is ILancaPool {
    /* TYPE DECLARATIONS */

    enum RedistributeLiquidityType {
        addPool,
        removePool
    }

    enum CLFRequestType {
        empty,
        startDeposit_getChildPoolsLiquidity,
        startWithdrawal_getChildPoolsLiquidity,
        withdrawal_requestLiquidityCollection,
        liquidityRedistribution
    }

    struct Pools {
        uint64 chainSelector;
        address poolAddress;
    }

    struct WithdrawRequest {
        address lpAddress;
        uint256 lpAmountToBurn;
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

    event WithdrawalCompleted(
        bytes32 indexed requestId,
        address indexed lpAddress,
        address token,
        uint256 amount
    );

    event CCIPSent(
        bytes32 indexed messageId,
        uint64 destinationChainSelector,
        address receiver,
        uint256 amount
    );

    event DepositInitiated(
        bytes32 indexed requestId,
        address indexed lpAddress,
        uint256 amount,
        uint256 deadline
    );

    event DepositCompleted(
        bytes32 indexed requestId,
        address indexed lpAddress,
        uint256 amount,
        uint256 lpTokensToMint
    );

    /* ERRORS */

    error SenderNotAllowed(address sender);
    error WithdrawalRequestAlreadyExists();
    error DepositAmountBelowMinimum();
    error DepositRequestNotReady();
    error DepositsOnTheWayArrayFull();
    error WithdrawAmountBelowMinimum();
    error MaxDepositCapReached();
    error NotAllowedToCompleteDeposit();
    error WithdrawRequestDoesntExist(bytes32 withdrawalId);
    error DepositDeadlinePassed();
    error OnlyRouterCanFulfill(address caller);
}
