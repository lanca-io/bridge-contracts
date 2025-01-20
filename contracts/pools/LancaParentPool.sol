// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {ILancaParentPool} from "./interfaces/ILancaParentPool.sol";
import {LancaParentPoolCommon} from "./LancaParentPoolCommon.sol";
import {LancaParentPoolStorage} from "../storages/LancaParentPoolStorage.sol";
import {LancaOwnable} from "../LancaOwnable.sol";
import {ICcip} from "../interfaces/ICcip.sol";

contract LancaParentPool is
    ILancaParentPool,
    CCIPReceiver,
    LancaParentPoolCommon,
    LancaParentPoolStorage,
    LancaOwnable
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
        LancaOwnable(owner)
    {
        i_linkToken = LinkTokenInterface(link);
        i_owner = _owner;
        i_parentPoolCLFCLA = ILancaParentPoolCLFCLA(parentPoolCLFCLA);
        i_clfRouter = clfRouter;
        i_automationForwarder = automationForwarder;
        i_collectLiquidityJsCodeHashSum = collectLiquidityJsCodeHashSum;
        i_distributeLiquidityJsCodeHashSum = distributeLiquidityJsCodeHashSum;
        i_donHostedSecretsSlotId = donHostedSecretsSlotId;
        i_donHostedSecretsVersion = donHostedSecretsVersion;
    }

    /* MODIFIERS */
    /**
     * @notice CCIP Modifier to check Chains And senders
     * @param _chainSelector Id of the source chain of the message
     * @param _sender address of the sender contract
     */
    modifier onlyAllowListedSenderOfChainSelector(uint64 chainSelector, address sender) {
        require(s_isSenderContractAllowed[chainSelector][sender], SenderNotAllowed(sender));
        _;
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
        s_depositRequests[clfRequestId] = ILancaParentPool.DepositRequest({
            lpAddress: msg.sender,
            usdcAmountToDeposit: usdcAmount,
            deadline: deadline
        });

        emit DepositInitiated(clfRequestId, msg.sender, usdcAmount, deadline);
    }

    /**
     * @notice Completes the deposit process initiated via startDeposit().
     * @notice This function needs to be called within the deadline of DEPOSIT_DEADLINE_SECONDS, set in startDeposit().
     * @param depositRequestId the ID of the deposit request
     */
    function completeDeposit(bytes32 depositRequestId) external onlyProxyContext {
        DepositRequest memory request = s_depositRequests[depositRequestId];
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
}
