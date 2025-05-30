// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {ILancaParentPool} from "./interfaces/ILancaParentPool.sol";
import {LancaParentPoolCommon} from "./LancaParentPoolCommon.sol";
import {LancaParentPoolStorageSetters} from "./storages/LancaParentPoolStorageSetters.sol";
import {ICcip} from "../common/interfaces/ICcip.sol";
import {ZERO_ADDRESS} from "../common/Constants.sol";
import {LibLanca} from "../common/libraries/LibLanca.sol";
import {LibErrors} from "../common/libraries/LibErrors.sol";
import {LibLanca} from "../common/libraries/LibLanca.sol";
import {ILancaParentPoolCLFCLAViewDelegate, ILancaParentPoolCLFCLA} from "./interfaces/ILancaParentPoolCLFCLA.sol";
import {LancaPool} from "./LancaPool.sol";
import {ILancaPoolCcip} from "./interfaces/ILancaPoolCcip.sol";

contract LancaParentPool is
    LancaPool,
    LancaParentPoolStorageSetters,
    LancaParentPoolCommon,
    CCIPReceiver,
    ILancaPoolCcip
{
    /* TYPE DECLARATIONS */
    using SafeERC20 for IERC20;
    using FunctionsRequest for FunctionsRequest.Request;

    struct TokenConfig {
        address link;
        address usdc;
        address lpToken;
    }

    struct AddressConfig {
        address ccipRouter;
        address automationForwarder;
        address owner;
        address lancaParentPoolCLFCLA;
        address lancaBridge;
        address clfRouter;
        address[3] messengers;
    }

    struct HashConfig {
        bytes32 distributeLiquidityJs;
        bytes32 ethersJs;
        bytes32 getChildPoolsLiquidityJsCodeHashSum;
    }

    struct PoolConfig {
        uint256 minDepositAmount;
        uint256 depositFeeAmount;
    }

    /* CONSTANT VARIABLES */
    uint256 internal constant DEPOSIT_DEADLINE_SECONDS = 60;
    uint32 private constant CCIP_SEND_GAS_LIMIT = 300_000;

    /* IMMUTABLE VARIABLES */
    LinkTokenInterface private immutable i_linkToken;
    ILancaParentPoolCLFCLA internal immutable i_lancaParentPoolCLFCLA;
    address internal immutable i_clfRouter;
    address internal immutable i_automationForwarder;
    bytes32 internal immutable i_distributeLiquidityJsCodeHashSum;
    bytes32 internal immutable i_getChildPoolsLiquidityJsHash;
    bytes32 internal immutable i_ethersJsHash;
    uint256 internal immutable i_minDepositAmount;
    uint256 internal immutable i_depositFeeAmount;

    constructor(
        TokenConfig memory tokenConfig,
        AddressConfig memory addressConfig,
        HashConfig memory hashConfig,
        PoolConfig memory poolConfig
    )
        LancaPool(tokenConfig.usdc, addressConfig.lancaBridge, addressConfig.messengers)
        LancaParentPoolStorageSetters(addressConfig.owner)
        LancaParentPoolCommon(tokenConfig.lpToken)
        CCIPReceiver(addressConfig.ccipRouter)
    {
        i_linkToken = LinkTokenInterface(tokenConfig.link);
        i_lancaParentPoolCLFCLA = ILancaParentPoolCLFCLA(addressConfig.lancaParentPoolCLFCLA);
        i_clfRouter = addressConfig.clfRouter;
        i_automationForwarder = addressConfig.automationForwarder;
        i_distributeLiquidityJsCodeHashSum = hashConfig.distributeLiquidityJs;
        i_getChildPoolsLiquidityJsHash = hashConfig.getChildPoolsLiquidityJsCodeHashSum;
        i_ethersJsHash = hashConfig.ethersJs;
        i_minDepositAmount = poolConfig.minDepositAmount;
        i_depositFeeAmount = poolConfig.depositFeeAmount;
    }

    /* EXTERNAL FUNCTIONS */
    receive() external payable {}

    function calculateLPTokensToMint(
        uint256 childPoolsBalance,
        uint256 amountToDeposit
    ) external view returns (uint256) {
        return _calculateLPTokensToMint(childPoolsBalance, amountToDeposit);
    }

    /**
     * @notice Allows a user to initiate the deposit. Currently supports USDC only.
     * @param usdcAmount amount to be deposited
     */
    function startDeposit(uint256 usdcAmount) external returns (bytes32) {
        require(usdcAmount >= i_minDepositAmount, DepositAmountBelowMinimum());

        uint256 liquidityCap = s_liquidityCap;

        require(
            usdcAmount +
                i_usdc.balanceOf(address(this)) -
                s_depositFeeAmount +
                s_loansInUse -
                s_withdrawAmountLocked <=
                liquidityCap,
            MaxDepositCapReached()
        );

        bytes[] memory args = new bytes[](4);
        args[0] = abi.encodePacked(i_getChildPoolsLiquidityJsHash);
        args[1] = abi.encodePacked(i_ethersJsHash);
        args[2] = abi.encodePacked(ClfRequestType.startDeposit_getChildPoolsLiquidity);
        args[3] = abi.encodePacked(block.chainid);

        bytes memory delegateCallArgs = abi.encodeWithSelector(
            ILancaParentPoolCLFCLA.sendCLFRequest.selector,
            args
        );
        bytes memory delegateCallResponse = LibLanca.safeDelegateCall(
            address(i_lancaParentPoolCLFCLA),
            delegateCallArgs
        );
        bytes32 clfRequestId = bytes32(delegateCallResponse);
        uint256 deadline = block.timestamp + DEPOSIT_DEADLINE_SECONDS;

        s_clfRequestTypes[clfRequestId] = ClfRequestType.startDeposit_getChildPoolsLiquidity;

        address lpAddress = msg.sender;

        s_depositRequests[clfRequestId].lpAddress = lpAddress;
        s_depositRequests[clfRequestId].usdcAmountToDeposit = usdcAmount;
        s_depositRequests[clfRequestId].deadline = deadline;

        emit DepositInitiated(clfRequestId, lpAddress, usdcAmount, deadline);

        return clfRequestId;
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
        uint256 usdcAmountAfterFee = usdcAmount - i_depositFeeAmount;
        uint256 childPoolsLiquiditySnapshot = request.childPoolsLiquiditySnapshot;

        require(msg.sender == lpAddress, NotAllowedToCompleteDeposit());
        require(block.timestamp <= request.deadline, DepositDeadlinePassed());
        require(childPoolsLiquiditySnapshot != 0, DepositRequestNotReady());

        uint256 lpTokensToMint = _calculateLPTokensToMint(
            childPoolsLiquiditySnapshot,
            usdcAmountAfterFee
        );

        i_usdc.safeTransferFrom(lpAddress, address(this), usdcAmount);

        i_lpToken.mint(lpAddress, lpTokensToMint);

        _distributeLiquidityToChildPools(usdcAmountAfterFee, ICcip.CcipTxType.deposit);

        s_depositFeeAmount += i_depositFeeAmount;

        emit DepositCompleted(depositRequestId, lpAddress, usdcAmount, lpTokensToMint);

        delete s_depositRequests[depositRequestId];
    }

    /* @notice function to manage the Cross-chain ConceroPool contracts
     * @param chainSelector chain identifications
     * @param pool address of the Cross-chain ConceroPool contract
     * @dev only owner can call it
     * @dev it's payable to save some gas.
     * @dev this functions is used on ConceroPool.sol
     */
    function setDstPool(
        uint64 chainSelector,
        address pool,
        bool isRebalancingNeeded
    ) external payable onlyOwner {
        require(
            s_dstPoolByChainSelector[chainSelector] != pool,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.sameAddress)
        );
        require(
            pool != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );

        s_poolChainSelectors.push(chainSelector);
        s_dstPoolByChainSelector[chainSelector] = pool;

        if (isRebalancingNeeded) {
            bytes32 distributeLiquidityRequestId = keccak256(
                abi.encodePacked(pool, chainSelector, RedistributeLiquidityType.addPool)
            );

            bytes[] memory args = new bytes[](7);
            args[0] = abi.encodePacked(i_distributeLiquidityJsCodeHashSum);
            args[1] = abi.encodePacked(i_ethersJsHash);
            args[2] = abi.encodePacked(ClfRequestType.liquidityRedistribution);
            args[3] = abi.encodePacked(chainSelector);
            args[4] = abi.encodePacked(distributeLiquidityRequestId);
            args[5] = abi.encodePacked(RedistributeLiquidityType.addPool);
            args[6] = abi.encodePacked(block.chainid);

            bytes memory delegateCallArgs = abi.encodeWithSelector(
                ILancaParentPoolCLFCLA.sendCLFRequest.selector,
                args
            );
            LibLanca.safeDelegateCall(address(i_lancaParentPoolCLFCLA), delegateCallArgs);
        }
    }

    /*
     * @notice Allows liquidity providers to initiate the withdrawal
     * @notice A cooldown period of WITHDRAW_DEADLINE_SECONDS needs to pass before the withdrawal can be completed.
     * @param lpAmount the amount of LP tokens to be burnt
     */
    function startWithdrawal(uint256 lpAmount) external {
        require(lpAmount >= 1 ether, WithdrawAmountBelowMinimum());
        address lpAddress = msg.sender;
        require(
            s_withdrawalIdByLPAddress[lpAddress] == bytes32(0),
            WithdrawalRequestAlreadyExists()
        );

        bytes[] memory args = new bytes[](4);
        args[0] = abi.encodePacked(i_getChildPoolsLiquidityJsHash);
        args[1] = abi.encodePacked(i_ethersJsHash);
        args[2] = abi.encodePacked(ClfRequestType.startWithdrawal_getChildPoolsLiquidity);
        args[3] = abi.encodePacked(block.chainid);

        IERC20(i_lpToken).safeTransferFrom(lpAddress, address(this), lpAmount);

        bytes memory delegateCallArgs = abi.encodeWithSelector(
            ILancaParentPoolCLFCLA.sendCLFRequest.selector,
            args
        );
        bytes memory delegateCallResponse = LibLanca.safeDelegateCall(
            address(i_lancaParentPoolCLFCLA),
            delegateCallArgs
        );
        bytes32 clfRequestId = bytes32(delegateCallResponse);

        bytes32 withdrawalId = keccak256(
            abi.encodePacked(lpAddress, lpAmount, block.number, clfRequestId)
        );

        s_clfRequestTypes[clfRequestId] = ClfRequestType.startWithdrawal_getChildPoolsLiquidity;

        // @dev partially initialize withdrawalRequest struct
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

        LibLanca.safeDelegateCall(address(i_lancaParentPoolCLFCLA), delegateCallArgs);
    }

    function withdrawDepositFees() external payable onlyOwner {
        uint256 amountToSend = s_depositFeeAmount;
        s_depositFeeAmount = 0;
        i_usdc.safeTransfer(i_owner, amountToSend);
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
        require(
            s_dstPoolByChainSelector[chainSelector] != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );
        require(
            !s_distributeLiquidityRequestProcessed[requestId],
            DistributeLiquidityRequestAlreadyProceeded()
        );
        s_distributeLiquidityRequestProcessed[requestId] = true;

        _ccipSend(chainSelector, amountToSend, ICcip.CcipTxType.liquidityRebalancing);
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
                removedPool = s_dstPoolByChainSelector[chainSelector];
                s_poolChainSelectors[i] = s_poolChainSelectors[poolChainSelectorsLast];
                s_poolChainSelectors.pop();
                delete s_dstPoolByChainSelector[chainSelector];
            }
        }
    }

    function processFailedWithdrawalRequest(bytes32 clfRequestId) external onlyOwner {
        bytes32 withdrawalId = s_withdrawalIdByCLFRequestId[clfRequestId];
        require(withdrawalId != bytes32(0), WithdrawRequestDoesntExist(clfRequestId));

        address lpAddress = s_withdrawRequests[withdrawalId].lpAddress;
        require(lpAddress != address(0), WithdrawRequestDoesntExist(withdrawalId));

        uint256 lpAmount = s_withdrawRequests[withdrawalId].lpAmountToBurn;
        require(lpAmount != 0, WithdrawRequestDoesntExist(withdrawalId));

        ILancaParentPool.ClfRequestType clfReqType = s_clfRequestTypes[clfRequestId];
        require(
            clfReqType == ILancaParentPool.ClfRequestType.startWithdrawal_getChildPoolsLiquidity,
            ILancaParentPoolCLFCLA.InvalidCLFRequestType()
        );

        delete s_withdrawRequests[withdrawalId];
        delete s_withdrawalIdByCLFRequestId[clfRequestId];
        delete s_withdrawalIdByLPAddress[lpAddress];
        delete s_clfRequestTypes[clfRequestId];

        IERC20(i_lpToken).safeTransfer(lpAddress, lpAmount);
    }

    /**
     * @notice Function to fulfill the Automation request for the pool upkeep.
     * @param performData the data for the upkeep to be performed
     */
    function performUpkeep(bytes calldata performData) external {
        require(
            msg.sender == i_automationForwarder,
            LibErrors.Unauthorized(LibErrors.UnauthorizedType.notAutomationForwarder)
        );

        bytes memory delegateCallArgs = abi.encodeWithSelector(
            AutomationCompatibleInterface.performUpkeep.selector,
            performData
        );

        LibLanca.safeDelegateCall(address(i_lancaParentPoolCLFCLA), delegateCallArgs);
    }

    /**
     * @notice Function to fulfill the Automation request for the pool upkeep with oracle result.
     * @param requestId the request id for the oracle data
     * @param delegateCallResponse the response from the oracle
     * @param err the error message if the oracle request failed
     */
    function handleOracleFulfillment(
        bytes32 requestId,
        bytes memory delegateCallResponse,
        bytes memory err
    ) external {
        require(msg.sender == i_clfRouter, OnlyRouterCanFulfill(msg.sender));

        bytes memory delegateCallArgs = abi.encodeWithSelector(
            ILancaParentPoolCLFCLA.fulfillRequestWrapper.selector,
            requestId,
            delegateCallResponse,
            err
        );

        LibLanca.safeDelegateCall(address(i_lancaParentPoolCLFCLA), delegateCallArgs);
    }

    /**
     * @notice Function to check if the pool needs upkeep.
     * @return a boolean indicating if the pool needs upkeep and the data for the upkeep
     */
    function checkUpkeepViaDelegate() external returns (bool, bytes memory) {
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            AutomationCompatibleInterface.checkUpkeep.selector,
            bytes("")
        );

        bytes memory delegateCallResponse = LibLanca.safeDelegateCall(
            address(i_lancaParentPoolCLFCLA),
            delegateCallArgs
        );

        return abi.decode(delegateCallResponse, (bool, bytes));
    }

    /**
     * @notice Function to calculate the withdrawable amount for the pool.
     * @param childPoolsBalance the balance of the child pools
     * @param clpAmount the amount of CLP tokens
     * @return the withdrawable amount
     */
    function calculateWithdrawableAmountViaDelegateCall(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external returns (uint256) {
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            ILancaParentPoolCLFCLA.calculateWithdrawableAmount.selector,
            childPoolsBalance,
            clpAmount
        );

        bytes memory delegateCallResponse = LibLanca.safeDelegateCall(
            address(i_lancaParentPoolCLFCLA),
            delegateCallArgs
        );

        return abi.decode(delegateCallResponse, (uint256));
    }

    /**
     * @notice Function to check if the pool needs upkeep.
     * @return a boolean indicating if the pool needs upkeep and the data for the upkeep
     */
    function checkUpkeep(bytes calldata) external view returns (bool, bytes memory) {
        (bool isTriggerNeeded, bytes memory data) = ILancaParentPoolCLFCLAViewDelegate(
            address(this)
        ).checkUpkeepViaDelegate();

        return (isTriggerNeeded, data);
    }

    /**
     * @notice Function to calculate the withdrawable amount for the pool.
     * @param childPoolsBalance the balance of the child pools
     * @param clpAmount the amount of CLP tokens
     * @return the withdrawable amount
     */
    function calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256) {
        return
            ILancaParentPoolCLFCLAViewDelegate(address(this))
                .calculateWithdrawableAmountViaDelegateCall(childPoolsBalance, clpAmount);
    }

    /* PUBLIC FUNCTIONS */

    /**
     * @notice Check if the pool is full.
     * @dev Returns true if the pool balance + deposit fee amount is greater than the liquidity cap.
     * @return true if the pool is full, false otherwise.
     */
    function isFull() public view returns (bool) {
        return
            i_minDepositAmount +
                i_usdc.balanceOf(address(this)) -
                s_depositFeeAmount +
                s_loansInUse -
                s_withdrawAmountLocked >
            s_liquidityCap;
    }

    function getMinDepositAmount() external view returns (uint256) {
        return i_minDepositAmount;
    }

    function getDepositDeadlineSeconds() external pure returns (uint256) {
        return DEPOSIT_DEADLINE_SECONDS;
    }

    /* INTERNAL FUNCTIONS */

    function _getLoansInUse() internal view override returns (uint256) {
        return s_loansInUse;
    }

    function _setLoansInUse(uint256 loansInUse) internal override {
        s_loansInUse = loansInUse;
    }

    function _getDstPoolByChainSelector(
        uint64 dstChainSelector
    ) internal view override returns (address) {
        return s_dstPoolByChainSelector[dstChainSelector];
    }

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
        uint256 parentPoolLiquidity = i_usdc.balanceOf(address(this)) +
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
        for (uint8 i = 1; i < MAX_DEPOSITS_ON_THE_WAY_COUNT; ++i) {
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
        onlyAllowListedSenderOfChainSelector(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        )
    {
        ICcip.CcipSettleMessage memory ccipTxData = abi.decode(
            any2EvmMessage.data,
            (ICcip.CcipSettleMessage)
        );
        uint256 ccipReceivedAmount = any2EvmMessage.destTokenAmounts[0].amount;
        address ccipReceivedToken = any2EvmMessage.destTokenAmounts[0].token;

        require(
            ccipReceivedToken == address(i_usdc),
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.notUsdcToken)
        );

        if (ccipTxData.ccipTxType == ICcip.CcipTxType.withdrawal) {
            bytes32 withdrawalId = abi.decode(ccipTxData.data, (bytes32));

            WithdrawRequest storage request = s_withdrawRequests[withdrawalId];

            require(request.amountToWithdraw != 0, WithdrawRequestDoesntExist(withdrawalId));

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
        } else {
            revert InvalidCcipTxType();
        }

        // @dev maybe we can use underlying ccipReceived event?
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
        ICcip.CcipTxType ccipTxType
    ) internal returns (bytes32) {
        ICcip.SettlementTx[] memory emptyBridgeTxArray;
        ICcip.CcipSettleMessage memory ccipTxData = ICcip.CcipSettleMessage({
            ccipTxType: ccipTxType,
            data: abi.encode(emptyBridgeTxArray)
        });

        address recipient = s_dstPoolByChainSelector[chainSelector];
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            recipient,
            address(i_usdc),
            amount,
            ccipTxData
        );

        uint256 ccipFeeAmount = IRouterClient(i_ccipRouter).getFee(chainSelector, evm2AnyMessage);

        i_usdc.approve(i_ccipRouter, amount);
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
        uint256 lpAmountToBurn = request.lpAmountToBurn;

        s_withdrawAmountLocked = s_withdrawAmountLocked > amountToWithdraw
            ? s_withdrawAmountLocked - amountToWithdraw
            : 0;

        delete s_withdrawalIdByLPAddress[lpAddress];
        delete s_withdrawRequests[withdrawalId];

        i_lpToken.burn(lpAmountToBurn);
        i_usdc.safeTransfer(lpAddress, amountToWithdraw);

        emit WithdrawalCompleted(withdrawalId, lpAddress, address(i_usdc), amountToWithdraw);
    }

    function _buildCCIPMessage(
        address recipient,
        address token,
        uint256 amount,
        ICcip.CcipSettleMessage memory ccipTxData
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
