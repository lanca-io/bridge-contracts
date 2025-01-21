// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {ILancaParentPool} from "../interfaces/pools/ILancaParentPool.sol";
import {LancaParentPoolCommon} from "./LancaParentPoolCommon.sol";
import {LancaParentPoolStorageSetters} from "./LancaParentPoolStorageSetters.sol";
import {ICcip} from "../interfaces/ICcip.sol";
import {ZERO_ADDRESS} from "../Constants.sol";

contract LancaParentPool is
    ILancaParentPool,
    CCIPReceiver,
    LancaParentPoolCommon,
    LancaParentPoolStorageSetters
{
    /* TYPE DECLARATIONS */
    using SafeERC20 for IERC20;

    /* IMMUTABLE VARIABLES */
    LinkTokenInterface private immutable i_linkToken;
    ILancaParentPoolCLFCLA internal immutable i_parentPoolCLFCLA;
    address internal immutable i_clfRouter;
    address internal immutable i_automationForwarder;
    bytes32 internal immutable i_collectLiquidityJsCodeHashSum;
    bytes32 internal immutable i_distributeLiquidityJsCodeHashSum;
    uint8 internal immutable i_donHostedSecretsSlotId;
    uint64 internal immutable i_donHostedSecretsVersion;

    /* CONSTANT VARIABLES */
    //TODO: move testnet-mainnet-dependent variables to immutables
    uint256 internal constant MIN_DEPOSIT = 100 * USDC_DECIMALS;
    uint256 internal constant DEPOSIT_DEADLINE_SECONDS = 60;
    uint256 internal constant DEPOSIT_FEE_USDC = 3 * USDC_DECIMALS;
    uint256 internal constant LP_FEE_FACTOR = 1000;
    uint32 private constant CCIP_SEND_GAS_LIMIT = 300_000;

    constructor(
        address parentPoolProxy,
        address parentPoolCLFCLA,
        address automationForwarder,
        address link,
        address ccipRouter,
        address usdc,
        address lpToken,
        address clfRouter,
        address owner,
        bytes32 collectLiquidityJsCodeHashSum,
        bytes32 distributeLiquidityJsCodeHashSum,
        uint8 donHostedSecretsSlotId,
        uint64 donHostedSecretsVersion,
        address[3] memory messengers
    )
        CCIPReceiver(ccipRouter)
        LancaParentPoolCommon(parentPoolProxy, lpToken, usdc, messengers)
        LancaParentPoolStorageSetters(owner)
    {
        i_linkToken = LinkTokenInterface(link);
        i_owner = owner;
        i_parentPoolCLFCLA = ILancaParentPoolCLFCLA(parentPoolCLFCLA);
        i_clfRouter = clfRouter;
        i_automationForwarder = automationForwarder;
        i_collectLiquidityJsCodeHashSum = collectLiquidityJsCodeHashSum;
        i_distributeLiquidityJsCodeHashSum = distributeLiquidityJsCodeHashSum;
        i_donHostedSecretsSlotId = donHostedSecretsSlotId;
        i_donHostedSecretsVersion = donHostedSecretsVersion;
    }

    //@dev TODO: move to LancaPoolStorageSetters
    /* MODIFIERS */
    /**
     * @notice CCIP Modifier to check Chains And senders
     * @param chainSelector Id of the source chain of the message
     * @param sender address of the sender contract
     */
    modifier onlyAllowListedSenderOfChainSelector(uint64 chainSelector, address sender) {
        require(s_isSenderContractAllowed[chainSelector][sender], SenderNotAllowed(sender));
        _;
    }

    /* EXTERNAL FUNCTIONS */

    /**
     * @notice Allows a user to initiate the deposit. Currently supports USDC only.
     * @param usdcAmount amount to be deposited
     */
    function startDeposit(uint256 usdcAmount) external {
        require(usdcAmount >= MIN_DEPOSIT, DepositAmountBelowMinimum(MIN_DEPOSIT));

        uint256 liquidityCap = s_liquidityCap;

        require(
            usdcAmount +
                i_USDC.balanceOf(address(this)) -
                s_depositFeeAmount +
                s_loansInUse -
                s_withdrawAmountLocked <=
                liquidityCap,
            MaxDepositCapReached(liquidityCap)
        );

        bytes[] memory args = new bytes[](3);
        args[0] = abi.encodePacked(s_getChildPoolsLiquidityJsCodeHashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);
        args[2] = abi.encodePacked(CLFRequestType.startDeposit_getChildPoolsLiquidity);

        bytes memory delegateCallArgs = abi.encodeWithSelector(
            ILancaParentPoolCLFCLA.sendCLFRequest.selector,
            args
        );
        bytes memory delegateCallResponse = LancaLib.safeDelegateCall(
            address(i_parentPoolCLFCLA),
            delegateCallArgs
        );
        bytes32 clfRequestId = bytes32(delegateCallResponse);
        uint256 deadline = block.timestamp + DEPOSIT_DEADLINE_SECONDS;

        s_clfRequestTypes[clfRequestId] = CLFRequestType.startDeposit_getChildPoolsLiquidity;
        s_depositRequests[clfRequestId].lpAddress = msg.sender;
        s_depositRequests[clfRequestId].usdcAmountToDeposit = usdcAmount;
        s_depositRequests[clfRequestId].deadline = deadline;

        emit DepositInitiated(clfRequestId, msg.sender, usdcAmount, deadline);
    }

    /**
     * @notice Completes the deposit process initiated via startDeposit().
     * @notice This function needs to be called within the deadline of DEPOSIT_DEADLINE_SECONDS, set in startDeposit().
     * @param depositRequestId the ID of the deposit request
     */
    function completeDeposit(bytes32 depositRequestId) external {
        DepositRequest storage request = s_depositRequests[depositRequestId];
        address lpAddress = request.lpAddress;
        uint256 usdcAmount = request.usdcAmountToDeposit;
        uint256 usdcAmountAfterFee = usdcAmount - DEPOSIT_FEE_USDC;
        uint256 childPoolsLiquiditySnapshot = request.childPoolsLiquiditySnapshot;

        require(msg.sender == lpAddress, NotAllowedToCompleteDeposit());
        require(block.timestamp <= request.deadline, DepositDeadlinePassed());
        require(childPoolsLiquiditySnapshot != 0, DepositRequestNotReady());

        uint256 lpTokensToMint = _calculateLPTokensToMint(
            childPoolsLiquiditySnapshot,
            usdcAmountAfterFee
        );

        i_USDC.safeTransferFrom(lpAddress, address(this), usdcAmount);

        i_lpToken.mint(lpAddress, lpTokensToMint);

        _distributeLiquidityToChildPools(usdcAmountAfterFee, ICcip.CcipTxType.deposit);

        s_depositFeeAmount += DEPOSIT_FEE_USDC;

        emit DepositCompleted(depositRequestId, lpAddress, usdcAmount, lpTokensToMint);

        delete s_depositRequests[depositRequestId];
    }

    /*
     * @notice Allows liquidity providers to initiate the withdrawal
     * @notice A cooldown period of WITHDRAW_DEADLINE_SECONDS needs to pass before the withdrawal can be completed.
     * @param lpAmount the amount of LP tokens to be burnt
     */
    function startWithdrawal(uint256 lpAmount) external {
        address lpAddress = msg.sender;
        require(lpAmount >= 1 ether, WithdrawAmountBelowMinimum(1 ether));
        require(
            s_withdrawalIdByLPAddress[lpAddress] == bytes32(0),
            WithdrawalRequestAlreadyExists()
        );

        bytes[] memory args = new bytes[](2);
        args[0] = abi.encodePacked(s_getChildPoolsLiquidityJsCodeHashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);

        IERC20(i_lpToken).safeTransferFrom(lpAddress, address(this), lpAmount);

        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IParentPoolCLFCLA.sendCLFRequest.selector,
            args
        );
        bytes memory delegateCallResponse = LancaLib.safeDelegateCall(
            address(i_parentPoolCLFCLA),
            delegateCallArgs
        );
        bytes32 clfRequestId = bytes32(delegateCallResponse);

        bytes32 withdrawalId = keccak256(
            abi.encodePacked(lpAddress, lpAmount, block.number, clfRequestId)
        );

        s_clfRequestTypes[clfRequestId] = CLFRequestType.startWithdrawal_getChildPoolsLiquidity;

        // partially initialise withdrawalRequest struct
        s_withdrawRequests[withdrawalId].lpAddress = lpAddress;
        s_withdrawRequests[withdrawalId].lpAmountToBurn = lpAmount;

        s_withdrawalIdByCLFRequestId[clfRequestId] = withdrawalId;
        s_withdrawalIdByLPAddress[lpAddress] = withdrawalId;
    }

    /**
     * @notice Allows the LP to retry the withdrawal request if the Chainlink Functions failed to execute it
     */
    function retryPerformWithdrawalRequest() external {
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            ILancaParentPoolCLFCLA.retryPerformWithdrawalRequest.selector
        );

        LancaLib.safeDelegateCall(address(i_parentPoolCLFCLA), delegateCallArgs);
    }

    /**
     * @notice Function called by Messenger to send USDC to a recently added pool.
     * @param chainSelector The chain selector of the new pool
     * @param amountToSend the amount to redistribute between pools.
     */
    function distributeLiquidity(
        uint64 chainSelector,
        uint256 amountToSend,
        bytes32 requestId
    ) external onlyMessenger {
        require(s_childPools[chainSelector] != ZERO_ADDRESS, InvalidAddress());
        require(
            !s_distributeLiquidityRequestProcessed[requestId],
            DistributeLiquidityRequestAlreadyProceeded(requestId)
        );
        s_distributeLiquidityRequestProcessed[requestId] = true;

        _ccipSend(chainSelector, amountToSend, ICcip.CcipTxType.liquidityRebalancing);
    }

    function takeLoan(address token, uint256 amount, address receiver) external payable {
        require(receiver != ZERO_ADDRESS, InvalidAddress());
        if (token != address(i_USDC)) revert NotUsdcToken();
        IERC20(token).safeTransfer(receiver, amount);
        s_loansInUse += amount;
    }

    /**
     * @notice function to manage the Cross-chain ConceroPool contracts
     * @param chainSelector chain identifications
     * @param pool address of the Cross-chain ConceroPool contract
     * @dev only owner can call it
     * @dev it's payable to save some gas.
     * @dev this functions is used on ConceroPool.sol
     */
    function setPools(
        uint64 chainSelector,
        address pool,
        bool isRebalancingNeeded
    ) external payable onlyOwner {
        if (s_childPools[chainSelector] == pool || pool == address(0)) {
            revert InvalidAddress();
        }

        s_poolChainSelectors.push(chainSelector);
        s_childPools[chainSelector] = pool;

        if (isRebalancingNeeded) {
            bytes32 distributeLiquidityRequestId = keccak256(
                abi.encodePacked(pool, chainSelector, RedistributeLiquidityType.addPool)
            );

            bytes[] memory args = new bytes[](7);
            args[0] = abi.encodePacked(s_distributeLiquidityJsCodeHashSum);
            args[1] = abi.encodePacked(s_ethersHashSum);
            args[2] = abi.encodePacked(CLFRequestType.liquidityRedistribution);
            args[3] = abi.encodePacked(chainSelector);
            args[4] = abi.encodePacked(distributeLiquidityRequestId);
            args[5] = abi.encodePacked(RedistributeLiquidityType.addPool);
            args[6] = abi.encodePacked(block.chainid);

            bytes memory delegateCallArgs = abi.encodeWithSelector(
                IParentPoolCLFCLA.sendCLFRequest.selector,
                args
            );
            LancaLib.safeDelegateCall(address(i_parentPoolCLFCLA), delegateCallArgs);
        }
    }

    /**
     * @notice Function to remove Cross-chain address disapproving transfers
     * @param chainSelector the CCIP chainSelector for the specific chain
     */
    function removePools(uint64 chainSelector) external payable onlyOwner {
        uint256 poolChainSelectorsLen = s_poolChainSelectors.length;
        uint256 poolChainSelectorsLast = poolChainSelectorsLen - 1;
        address removedPool;

        for (uint256 i; i < poolChainSelectorsLen; ++i) {
            if (s_poolChainSelectors[i] == chainSelector) {
                removedPool = s_childPools[chainSelector];
                s_poolChainSelectors[i] = s_poolChainSelectors[poolChainSelectorsLast];
                s_poolChainSelectors.pop();
                delete s_childPools[chainSelector];
            }
        }
    }

    /* PUBLIC FUNCTIONS */
    /**
     * @notice getter function to calculate Destination fee amount on Source
     * @param amount the amount of tokens to calculate over
     * @return the fee amount
     */
    function getDstTotalFeeInUsdc(uint256 amount) public pure override returns (uint256) {
        return (amount * PRECISION_HANDLER) / LP_FEE_FACTOR / PRECISION_HANDLER;
    }

    /* INTERNAL FUNCTIONS */

    /**
     * @notice Function called by Chainlink Functions fulfillRequest to update deposit information
     * @param childPoolsTotalBalance The total cross chain balance of child pools
     * @param amountToDeposit the amount of USDC deposited
     * @dev This function must be called only by an allowed Messenger & must not revert
     * @dev totalUSDCCrossChainBalance MUST have 10**6 decimals.
     */
    function _calculateLPTokensToMint(
        uint256 childPoolsTotalBalance,
        uint256 amountToDeposit
    ) private view returns (uint256) {
        uint256 parentPoolLiquidity = i_USDC.balanceOf(address(this)) +
            s_loansInUse +
            s_depositsOnTheWayAmount -
            s_depositFeeAmount;
        //TODO: add withdrawalsOnTheWay

        uint256 totalCrossChainLiquidity = childPoolsTotalBalance + parentPoolLiquidity;
        uint256 totalLPSupply = i_lpToken.totalSupply();

        if (totalLPSupply == 0) {
            return _convertToLPTokenDecimals(amountToDeposit);
        }

        uint256 crossChainBalanceConverted = _convertToLPTokenDecimals(totalCrossChainLiquidity);
        uint256 amountDepositedConverted = _convertToLPTokenDecimals(amountToDeposit);

        return
            (((crossChainBalanceConverted + amountDepositedConverted) * totalLPSupply) /
                crossChainBalanceConverted) - totalLPSupply;
    }

    /**
     * @notice helper function to distribute liquidity after LP deposits.
     * @param amountToDistributeUSDC amount of USDC should be distributed to the pools.
     */
    function _distributeLiquidityToChildPools(
        uint256 amountToDistributeUSDC,
        ICcip.CcipTxType ccipTxType
    ) internal {
        uint64[] memory poolChainSelectors = s_poolChainSelectors;

        uint256 childPoolsCount = poolChainSelectors.length;
        uint256 amountToDistributePerPool = ((amountToDistributeUSDC * PRECISION_HANDLER) /
            (childPoolsCount + 1)) / PRECISION_HANDLER;

        for (uint256 i; i < childPoolsCount; ) {
            bytes32 ccipMessageId = _ccipSend(
                poolChainSelectors[i],
                amountToDistributePerPool,
                ccipTxType
            );

            _addDepositOnTheWay(ccipMessageId, poolChainSelectors[i], amountToDistributePerPool);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice adds a new DepositOnTheWay struct to the s_depositsOnTheWayArray.
     * @dev This function will either add a new element to the array if there is available space,
     * or overwrite the lowest unused DepositOnTheWay struct.
     * @param ccipMessageId the CCIP Message ID associated with the deposit
     * @param chainSelector the chain selector of the pool that will receive the deposit
     * @param amount the amount of USDC being deposited
     */
    function _addDepositOnTheWay(
        bytes32 ccipMessageId,
        uint64 chainSelector,
        uint256 amount
    ) internal {
        uint8 index = s_latestDepositOnTheWayIndex < (MAX_DEPOSITS_ON_THE_WAY_COUNT - 1)
            ? ++s_latestDepositOnTheWayIndex
            : _findLowestDepositOnTheWayUnusedIndex();

        s_depositsOnTheWayArray[index] = DepositOnTheWay({
            ccipMessageId: ccipMessageId,
            chainSelector: chainSelector,
            amount: amount
        });

        s_depositsOnTheWayAmount += amount;
    }

    function _findLowestDepositOnTheWayUnusedIndex() internal returns (uint8) {
        uint8 index;
        for (uint8 i = 1; i < MAX_DEPOSITS_ON_THE_WAY_COUNT; i++) {
            if (s_depositsOnTheWayArray[i].ccipMessageId == bytes32(0)) {
                index = i;
                s_latestDepositOnTheWayIndex = i;
                break;
            }
        }

        require(index != 0, DepositsOnTheWayArrayFull());

        return index;
    }

    /**
     * @notice CCIP function to receive bridged values
     * @param any2EvmMessage the CCIP message
     * @dev only allowed chains and sender must be able to deliver a message in this function.
     */
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
        onlyAllowlistedSenderOfChainSelector(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        )
    {
        ICcip.CcipTxData memory ccipTxData = abi.decode(any2EvmMessage.data, (ICcip.CcipTxData));
        uint256 ccipReceivedAmount = any2EvmMessage.destTokenAmounts[0].amount;
        address ccipReceivedToken = any2EvmMessage.destTokenAmounts[0].token;

        if (ccipReceivedToken != address(i_USDC)) {
            revert NotUsdcToken();
        }

        if (ccipTxData.ccipTxType == ICcip.CcipTxType.batchedSettlement) {
            IConceroBridge.CcipSettlementTx[] memory settlementTxs = abi.decode(
                ccipTxData.data,
                (IConceroBridge.CcipSettlementTx[])
            );
            for (uint256 i; i < settlementTxs.length; ++i) {
                bytes32 txId = settlementTxs[i].id;
                uint256 txAmount = settlementTxs[i].amount;
                bool isTxConfirmed = IInfraOrchestrator(i_infraProxy).isTxConfirmed(txId);

                if (isTxConfirmed) {
                    txAmount -= getDstTotalFeeInUsdc(txAmount);
                    s_loansInUse -= txAmount;
                } else {
                    IInfraOrchestrator(i_infraProxy).confirmTx(txId);
                    i_USDC.safeTransfer(settlementTxs[i].recipient, txAmount);
                    emit FailedExecutionLayerTxSettled(settlementTxs[i].id);
                }
            }
        } else if (ccipTxData.ccipTxType == ICcip.CcipTxType.withdrawal) {
            bytes32 withdrawalId = abi.decode(ccipTxData.data, (bytes32));

            WithdrawRequest storage request = s_withdrawRequests[withdrawalId];

            if (request.amountToWithdraw == 0) {
                revert WithdrawRequestDoesntExist(withdrawalId);
            }

            request.remainingLiquidityFromChildPools = request.remainingLiquidityFromChildPools >=
                ccipReceivedAmount
                ? request.remainingLiquidityFromChildPools - ccipReceivedAmount
                : 0;

            s_withdrawalsOnTheWayAmount = s_withdrawalsOnTheWayAmount >= ccipReceivedAmount
                ? s_withdrawalsOnTheWayAmount - ccipReceivedAmount
                : 0;

            s_withdrawAmountLocked += ccipReceivedAmount;

            if (request.remainingLiquidityFromChildPools < 10) {
                _completeWithdrawal(withdrawalId);
            }
        }

        // TODO: maybe we can use underlying ccipReceived event?
        emit CCIPReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            ccipReceivedToken,
            ccipReceivedAmount
        );
    }

    function _ccipSend(
        uint64 chainSelector,
        uint256 amount,
        ICCIP.CcipTxType ccipTxType
    ) internal override returns (bytes32) {
        IInfraStorage.SettlementTx[] memory emptyBridgeTxArray;
        ICCIP.CcipTxData memory ccipTxData = ICCIP.CcipTxData({
            ccipTxType: ccipTxType,
            data: abi.encode(emptyBridgeTxArray)
        });

        address recipient = s_childPools[chainSelector];
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            recipient,
            address(i_USDC),
            amount,
            ccipTxData
        );

        uint256 ccipFeeAmount = IRouterClient(i_ccipRouter).getFee(chainSelector, evm2AnyMessage);

        i_USDC.approve(i_ccipRouter, amount);
        i_linkToken.approve(i_ccipRouter, ccipFeeAmount);

        return IRouterClient(i_ccipRouter).ccipSend(chainSelector, evm2AnyMessage);
    }

    /**
     * @notice Function to process the withdraw request
     * @param withdrawalId the id of the withdraw request
     */
    function _completeWithdrawal(bytes32 withdrawalId) internal {
        WithdrawRequest storage request = s_withdrawRequests[withdrawalId];
        uint256 amountToWithdraw = request.amountToWithdraw;
        address lpAddress = request.lpAddress;

        i_lpToken.burn(request.lpAmountToBurn);
        i_USDC.safeTransfer(lpAddress, amountToWithdraw);

        s_withdrawAmountLocked = s_withdrawAmountLocked > amountToWithdraw
            ? s_withdrawAmountLocked - amountToWithdraw
            : 0;

        delete s_withdrawalIdByLPAddress[lpAddress];
        delete s_withdrawRequests[withdrawalId];

        emit WithdrawalCompleted(withdrawalId, lpAddress, address(i_USDC), amountToWithdraw);
    }

    function _buildCCIPMessage(
        address recipient,
        address token,
        uint256 amount,
        ICCIP.CcipTxData memory ccipTxData
    ) internal view returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});

        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(recipient),
                data: abi.encode(ccipTxData),
                tokenAmounts: tokenAmounts,
                extraArgs: Client._argsToBytes(
                    Client.EVMExtraArgsV1({gasLimit: CCIP_SEND_GAS_LIMIT})
                ),
                feeToken: address(i_linkToken)
            });
    }
}
