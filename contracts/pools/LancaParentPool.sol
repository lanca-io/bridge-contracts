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
    IParentPoolCLFCLA internal immutable i_parentPoolCLFCLA;
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
        i_parentPoolCLFCLA = IParentPoolCLFCLA(parentPoolCLFCLA);
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
        if (usdcAmount < MIN_DEPOSIT) {
            revert DepositAmountBelowMinimum(MIN_DEPOSIT);
        }

        uint256 liquidityCap = s_liquidityCap;

        if (
            usdcAmount +
                i_USDC.balanceOf(address(this)) -
                s_depositFeeAmount +
                s_loansInUse -
                s_withdrawAmountLocked >
            liquidityCap
        ) {
            revert MaxDepositCapReached(liquidityCap);
        }

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
}
