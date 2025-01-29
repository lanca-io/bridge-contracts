// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {ILancaParentPool} from "../interfaces/pools/ILancaParentPool.sol";
import {LancaParentPoolCommon} from "./LancaParentPoolCommon.sol";
import {LancaParentPoolStorageSetters} from "./LancaParentPoolStorageSetters.sol";
import {ICcip} from "../interfaces/ICcip.sol";
import {ZERO_ADDRESS} from "../Constants.sol";
import {LancaLib} from "../libraries/LancaLib.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";

contract LancaParentPool is
    AutomationCompatible,
    FunctionsClient,
    CCIPReceiver,
    LancaParentPoolCommon,
    LancaParentPoolStorageSetters
{
    /* TYPE DECLARATIONS */
    using SafeERC20 for IERC20;
    using FunctionsRequest for FunctionsRequest.Request;
    using ErrorsLib for *;

    /* CONSTANT VARIABLES */
    //TODO: move testnet-mainnet-dependent variables to immutables
    string internal constant JS_CODE =
        "try{const [b,o,f]=bytesArgs;const m='https://raw.githubusercontent.com/';const u=m+'ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js';const q=m+'concero/contracts-v1/'+'release'+`/tasks/CLFScripts/dist/pool/${f==='0x02' ? 'withdrawalLiquidityCollection':f==='0x03' ? 'redistributePoolsLiquidity':'getChildPoolsLiquidity'}.min.js`;const [t,p]=await Promise.all([fetch(u),fetch(q)]);const [e,c]=await Promise.all([t.text(),p.text()]);const g=async s=>{return('0x'+Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s)))).map(v=>('0'+v.toString(16)).slice(-2).toLowerCase()).join(''));};const r=await g(c);const x=await g(e);if(r===b.toLowerCase()&& x===o.toLowerCase()){const ethers=new Function(e+';return ethers;')();return await eval(c);}throw new Error(`${r}!=${b}||${x}!=${o}`);}catch(e){throw new Error(e.message.slice(0,255));}";
    uint256 internal constant MIN_DEPOSIT = 100 * USDC_DECIMALS;
    uint256 internal constant DEPOSIT_DEADLINE_SECONDS = 60;
    uint256 internal constant DEPOSIT_FEE_USDC = 3 * USDC_DECIMALS;
    uint256 internal constant LP_FEE_FACTOR = 1000;
    uint32 private constant CCIP_SEND_GAS_LIMIT = 300_000;
    uint256 internal constant CCIP_ESTIMATED_TIME_TO_COMPLETE = 30 minutes;
    uint32 internal constant CLF_CALLBACK_GAS_LIMIT = 2_000_000;

    /* IMMUTABLE VARIABLES */
    LinkTokenInterface private immutable i_linkToken;
    address internal immutable i_clfRouter;
    address internal immutable i_automationForwarder;
    bytes32 internal immutable i_collectLiquidityJsCodeHashSum;
    bytes32 internal immutable i_distributeLiquidityJsCodeHashSum;
    uint8 internal immutable i_donHostedSecretsSlotId;
    uint64 internal immutable i_donHostedSecretsVersion;

    constructor(
        address parentPoolProxy,
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
        FunctionsClient(clfRouter)
        CCIPReceiver(ccipRouter)
        LancaParentPoolCommon(parentPoolProxy, lpToken, usdc, messengers)
        LancaParentPoolStorageSetters(owner)
    {
        i_linkToken = LinkTokenInterface(link);
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
    receive() external payable {}

    function handleOracleFulfillment(
        bytes32 requestId,
        bytes memory delegateCallResponse,
        bytes memory err
    ) external {
        require(msg.sender == i_clfRouter, OnlyRouterCanFulfill());
        fulfillRequest(requestId, delegateCallResponse, err);
    }

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

        bytes32 clfRequestId = sendCLFRequest(args);
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
        require(
            s_childPools[chainSelector] != pool && pool != ZERO_ADDRESS,
            ErrorsLib.InvalidAddress(ErrorsLib.InvalidAddressType.zeroAddress)
        );

        s_poolChainSelectors.push(chainSelector);
        s_childPools[chainSelector] = pool;

        if (isRebalancingNeeded) {
            bytes32 distributeLiquidityRequestId = keccak256(
                abi.encodePacked(pool, chainSelector, RedistributeLiquidityType.addPool)
            );

            bytes[] memory args = new bytes[](7);
            args[0] = abi.encodePacked(i_distributeLiquidityJsCodeHashSum);
            args[1] = abi.encodePacked(s_ethersHashSum);
            args[2] = abi.encodePacked(CLFRequestType.liquidityRedistribution);
            args[3] = abi.encodePacked(chainSelector);
            args[4] = abi.encodePacked(distributeLiquidityRequestId);
            args[5] = abi.encodePacked(RedistributeLiquidityType.addPool);
            args[6] = abi.encodePacked(block.chainid);

            sendCLFRequest(args);
        }
    }

    function calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256) {
        return _calculateWithdrawableAmount(childPoolsBalance, clpAmount, i_lpToken.totalSupply());
    }

    function fulfillRequestWrapper(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) external {
        fulfillRequest(requestId, response, err);
    }

    /**
     * @notice Chainlink Automation function that will perform storage update and call Chainlink Functions
     * @param performData the performData encoded in checkUpkeep function
     * @dev this function must be called only by the Chainlink Forwarder unique address
     */
    function performUpkeep(bytes calldata performData) external override {
        bytes32 withdrawalId = abi.decode(performData, (bytes32));

        if (withdrawalId == bytes32(0)) {
            revert WithdrawalRequestDoesntExist(withdrawalId);
        }

        if (block.timestamp < s_withdrawRequests[withdrawalId].triggeredAtTimestamp) {
            revert WithdrawalRequestNotReady(withdrawalId);
        }

        if (s_withdrawTriggered[withdrawalId]) {
            revert WithdrawalAlreadyTriggered(withdrawalId);
        } else {
            s_withdrawTriggered[withdrawalId] = true;
        }

        uint256 liquidityRequestedFromEachPool = s_withdrawRequests[withdrawalId]
            .liquidityRequestedFromEachPool;
        if (liquidityRequestedFromEachPool == 0) {
            revert WithdrawalRequestDoesntExist(withdrawalId);
        }

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

        bytes32 clfRequestId = sendCLFRequest(args);

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
        bytes32 withdrawalId = s_withdrawalIdByLPAddress[msg.sender];

        if (msg.sender != s_withdrawRequests[withdrawalId].lpAddress) {
            revert Unauthorized();
        }

        uint256 liquidityRequestedFromEachPool = s_withdrawRequests[withdrawalId]
            .liquidityRequestedFromEachPool;
        if (liquidityRequestedFromEachPool == 0) {
            revert WithdrawalRequestDoesntExist(withdrawalId);
        }

        if (s_withdrawRequests[withdrawalId].remainingLiquidityFromChildPools < 10) {
            revert WithdrawalAlreadyPerformed(withdrawalId);
        }

        if (
            block.timestamp <
            s_withdrawRequests[withdrawalId].triggeredAtTimestamp + CCIP_ESTIMATED_TIME_TO_COMPLETE
        ) {
            revert WithdrawalRequestNotReady(withdrawalId);
        }

        bytes32 reqId = _sendLiquidityCollectionRequest(
            withdrawalId,
            liquidityRequestedFromEachPool
        );

        emit RetryWithdrawalPerformed(reqId);
    }

    function withdrawDepositFees() external payable onlyOwner {
        uint256 amountToSend = s_depositFeeAmount;
        s_depositFeeAmount = 0;
        i_USDC.safeTransfer(i_owner, amountToSend);
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
            s_childPools[chainSelector] != ZERO_ADDRESS,
            ErrorsLib.InvalidAddress(ErrorsLib.InvalidAddressType.zeroAddress)
        );
        require(
            !s_distributeLiquidityRequestProcessed[requestId],
            DistributeLiquidityRequestAlreadyProceeded(requestId)
        );
        s_distributeLiquidityRequestProcessed[requestId] = true;

        _ccipSend(chainSelector, amountToSend, ICcip.CcipTxType.liquidityRebalancing);
    }

    function takeLoan(address token, uint256 amount, address receiver) external payable {
        require(
            receiver != ZERO_ADDRESS,
            ErrorsLib.InvalidAddress(ErrorsLib.InvalidAddressType.zeroAddress)
        );
        require(token == address(i_USDC), NotUsdcToken());
        IERC20(token).safeTransfer(receiver, amount);
        s_loansInUse += amount;
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

    function getDepositsOnTheWay()
        external
        view
        returns (ILancaParentPool.DepositOnTheWay[MAX_DEPOSITS_ON_THE_WAY_COUNT] memory)
    {
        return s_depositsOnTheWayArray;
    }

    /* PUBLIC FUNCTIONS */
    /**
     * @notice getter function to calculate Destination fee amount on Source
     * @param amount the amount of tokens to calculate over
     * @return the fee amount
     */
    function getDstTotalFeeInUsdc(uint256 amount) public pure returns (uint256) {
        return (amount * PRECISION_HANDLER) / LP_FEE_FACTOR / PRECISION_HANDLER;
    }

    /* INTERNAL FUNCTIONS */

    function _handleStartDepositCLFFulfill(bytes32 requestId, bytes memory response) internal {
        ILancaParentPool.DepositRequest storage request = s_depositRequests[requestId];
        (
            uint256 childPoolsLiquidity,
            bytes1[] memory depositsOnTheWayIdsToDelete
        ) = _decodeCLFResponse(response);

        request.childPoolsLiquiditySnapshot = childPoolsLiquidity;

        _deleteDepositsOnTheWayByIndexes(depositsOnTheWayIdsToDelete);
    }

    function _deleteDepositsOnTheWayByIndexes(
        bytes1[] memory depositsOnTheWayIndexesToDelete
    ) internal {
        uint256 depositsOnTheWayIndexesToDeleteLength = depositsOnTheWayIndexesToDelete.length;

        if (depositsOnTheWayIndexesToDeleteLength == 0) {
            return;
        }

        uint256 s_depositsOnTheWayArrayLength = s_depositsOnTheWayArray.length;

        for (uint256 i; i < depositsOnTheWayIndexesToDeleteLength; i++) {
            uint8 indexToDelete = uint8(depositsOnTheWayIndexesToDelete[i]);

            if (indexToDelete >= s_depositsOnTheWayArrayLength) {
                continue;
            }

            s_depositsOnTheWayAmount -= s_depositsOnTheWayArray[indexToDelete].amount;
            delete s_depositsOnTheWayArray[indexToDelete];
        }
    }

    /**
     * @notice sends a request to Chainlink Functions
     * @param args the arguments for the request as bytes array
     * @return the request ID
     */
    function sendCLFRequest(bytes[] memory args) internal returns (bytes32) {
        return _sendRequest(args);
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

    /// @dev taken from the ConceroAutomation::fulfillRequest logic
    function _handleAutomationCLFFulfill(bytes32 requestId) internal {
        bytes32 withdrawalId = s_withdrawalIdByCLFRequestId[requestId];

        for (uint256 i; i < s_withdrawalRequestIds.length; ++i) {
            if (s_withdrawalRequestIds[i] == withdrawalId) {
                s_withdrawalRequestIds[i] = s_withdrawalRequestIds[
                    s_withdrawalRequestIds.length - 1
                ];
                s_withdrawalRequestIds.pop();
            }
        }
    }

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
            for (uint256 i = 32; i < response.length; i++) {
                depositsOnTheWayIdsToDelete[i - 32] = response[i];
            }

            return (totalBalance, depositsOnTheWayIdsToDelete);
        }
    }

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
        withdrawalRequest.triggeredAtTimestamp = block.timestamp + WITHDRAWAL_COOLDOWN_SECONDS;

        s_withdrawalRequestIds.push(withdrawalId);
        emit WithdrawalRequestInitiated(
            withdrawalId,
            withdrawalRequest.lpAddress,
            block.timestamp + WITHDRAWAL_COOLDOWN_SECONDS
        );
    }

    /**
     * @notice Function to send a Request to Chainlink Functions
     * @param args the arguments for the request as bytes array
     */
    function _sendRequest(bytes[] memory args) internal returns (bytes32) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(JS_CODE);
        req.addDONHostedSecrets(i_donHostedSecretsSlotId, i_donHostedSecretsVersion);
        req.setBytesArgs(args);

        return _sendRequest(req.encodeCBOR(), i_clfSubId, CLF_CALLBACK_GAS_LIMIT, i_clfDonId);
    }

    function _calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount,
        uint256 lpSupply
    ) internal view returns (uint256) {
        uint256 parentPoolLiquidity = i_USDC.balanceOf(address(this)) +
            s_loansInUse +
            s_depositsOnTheWayAmount -
            s_depositFeeAmount;
        uint256 totalCrossChainLiquidity = childPoolsBalance + parentPoolLiquidity;

        //USDC_WITHDRAWABLE = POOL_BALANCE x (LP_INPUT_AMOUNT / TOTAL_LP)
        uint256 amountUsdcToWithdraw = (((_convertToLPTokenDecimals(totalCrossChainLiquidity) *
            clpAmount) * PRECISION_HANDLER) / lpSupply) / PRECISION_HANDLER;

        return _convertToUSDCTokenDecimals(amountUsdcToWithdraw);
    }

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

    function _addWithdrawalOnTheWayAmountById(bytes32 withdrawalId) internal {
        uint256 awaitedChildPoolsWithdrawalAmount = s_withdrawRequests[withdrawalId]
            .amountToWithdraw - s_withdrawRequests[withdrawalId].liquidityRequestedFromEachPool;

        if (awaitedChildPoolsWithdrawalAmount == 0) {
            revert WithdrawalRequestDoesntExist(withdrawalId);
        }

        s_withdrawalsOnTheWayAmount += awaitedChildPoolsWithdrawalAmount;
    }

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

                IERC20(i_lpToken).safeTransfer(lpAddress, lpAmountToBurn);

                delete s_withdrawRequests[withdrawalId];
                delete s_withdrawalIdByLPAddress[lpAddress];
                delete s_withdrawalIdByCLFRequestId[requestId];
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
            }
        }

        delete s_clfRequestTypes[requestId];
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

        require(ccipReceivedToken == address(i_USDC), NotUsdcToken());

        if (ccipTxData.ccipTxType == ICcip.CcipTxType.batchedSettlement) {
            ICcip.CcipSettlementTx[] memory settlementTxs = abi.decode(
                ccipTxData.data,
                (ICcip.CcipSettlementTx[])
            );
            for (uint256 i; i < settlementTxs.length; ++i) {
                bytes32 txId = settlementTxs[i].id;
                uint256 txAmount = settlementTxs[i].amount;
                /// @dev we dont have infra orchestrator
                //bool isTxConfirmed = IInfraOrchestrator(i_infraProxy).isTxConfirmed(txId);
                /// @dev change it
                bool isTxConfirmed = true;

                if (isTxConfirmed) {
                    txAmount -= getDstTotalFeeInUsdc(txAmount);
                    s_loansInUse -= txAmount;
                } else {
                    /// @dev we dont have infra orchestrator
                    //IInfraOrchestrator(i_infraProxy).confirmTx(txId);
                    i_USDC.safeTransfer(settlementTxs[i].recipient, txAmount);
                    emit FailedExecutionLayerTxSettled(settlementTxs[i].id);
                }
            }
        } else if (ccipTxData.ccipTxType == ICcip.CcipTxType.withdrawal) {
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

            /// @dev why this number is 10?
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
        ICcip.CcipTxType ccipTxType
    ) internal override returns (bytes32) {
        ICcip.SettlementTx[] memory emptyBridgeTxArray;
        ICcip.CcipSettleMessage memory ccipTxData = ICcip.CcipSettleMessage({
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
        ICcip.CcipSettleMessage memory ccipTxData
    ) internal view returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});

        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(recipient),
                data: abi.encode(ccipTxData),
                tokenAmounts: tokenAmounts,
                extraArgs: Client.argsToBytes(
                    Client.EVMExtraArgsV1({gasLimit: CCIP_SEND_GAS_LIMIT})
                ),
                feeToken: address(i_linkToken)
            });
    }
}
