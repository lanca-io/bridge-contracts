// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILancaBridge} from "../bridge/interfaces/ILancaBridge.sol";
import {ILancaIntegration} from "./interfaces/ILancaIntegration.sol";
import {ILancaDexSwap} from "./interfaces/ILancaDexSwap.sol";
import {LancaOrchestratorStorage} from "./storages/LancaOrchestratorStorage.sol";
import {ICcip} from "../common/interfaces/ICcip.sol";
import {LibLanca} from "../common/libraries/LibLanca.sol";
import {ZERO_ADDRESS} from "../common/Constants.sol";
import {LancaBridgeClient} from "../LancaBridgeClient/LancaBridgeClient.sol";
import {LancaOwnable} from "../common/LancaOwnable.sol";
import {LibErrors} from "../common/libraries/LibErrors.sol";
import {LibZip} from "solady/src/utils/LibZip.sol";

contract LancaOrchestrator is
    LancaOrchestratorStorage,
    ILancaIntegration,
    LancaBridgeClient,
    LancaOwnable
{
    using SafeERC20 for IERC20;

    /* TYPES */

    struct BridgeData {
        address token;
        address receiver;
        uint256 amount;
        uint64 dstChainSelector;
        bytes compressedDstSwapData;
    }

    /* CONSTANTS */
    uint16 internal constant MAX_INTEGRATOR_FEE_BPS = 1_000;
    uint16 internal constant BPS_DIVISOR = 10_000;
    uint24 internal constant DST_CHAIN_GAS_LIMIT = 1_200_000;
    uint16 internal constant LANCA_FEE_FACTOR = 1000;

    /* IMMUTABLES */
    address internal immutable i_usdc;
    address internal immutable i_dexSwap;
    uint64 internal immutable i_chainSelector;

    /* ERRORS */
    error InvalidBridgeToken();
    error InvalidBridgeData();
    error InvalidRecipient();
    error TransferFailed();
    error InvalidLancaBridgeSender();
    error InvalidLancaBridgeSrcChain();
    error InvalidChainSelector();

    /* EVENTS */
    // TODO: move this events to the LancaBridge in future
    event LancaBridgeReceived(bytes32 indexed id, address token, address receiver, uint256 amount);
    event LancaBridgeSent(
        bytes32 indexed conceroMessageId,
        address token,
        uint256 amount,
        address receiver,
        uint64 dstChainSelector
    );

    event DstSwapFailed(bytes32);

    /**
     * @dev Constructor for the LancaOrchestrator contract.
     * @param usdc The address of the USDC token.
     * @param lancaBridge The address of the LancaBridge contract.
     */
    constructor(
        address usdc,
        address lancaBridge,
        address dexSwap,
        uint64 chainSelector
    ) LancaBridgeClient(lancaBridge) LancaOwnable(msg.sender) {
        i_usdc = usdc;
        i_chainSelector = chainSelector;
        i_dexSwap = dexSwap;
    }

    receive() external payable {}

    /* MODIFIERS */

    modifier validateBridgeData(BridgeData memory bridgeData) {
        require(
            bridgeData.amount != 0 &&
                bridgeData.receiver != ZERO_ADDRESS &&
                bridgeData.token == i_usdc,
            InvalidBridgeData()
        );
        _;
    }

    /* EXTERNAL FUNCTIONS */

    /**
     * @notice Performs a token swap followed by a cross-chain bridge operation.
     * @param bridgeData The data required for the bridging process.
     * @param swapData The list of swap operations to perform before bridging.
     * @param integration Integration details for fee calculation.
     */
    function swapAndBridge(
        BridgeData memory bridgeData,
        ILancaDexSwap.SwapData[] memory swapData,
        Integration calldata integration
    ) external payable nonReentrant validateBridgeData(bridgeData) {
        require(swapData[swapData.length - 1].toToken == i_usdc, ILancaDexSwap.InvalidSwapData());

        LibLanca.transferTokenFromUser(swapData[0].fromToken, swapData[0].fromAmount);
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            ILancaDexSwap.performSwaps.selector,
            swapData,
            address(this)
        );

        uint256 usdcReceived = abi.decode(
            LibLanca.safeDelegateCall(i_dexSwap, delegateCallArgs),
            (uint256)
        );

        bridgeData.amount = usdcReceived;
        _bridge(bridgeData, integration);
    }

    function bridge(
        BridgeData memory bridgeData,
        Integration calldata integration
    ) external nonReentrant validateBridgeData(bridgeData) {
        IERC20(bridgeData.token).safeTransferFrom(msg.sender, address(this), bridgeData.amount);
        _bridge(bridgeData, integration);
    }

    function swap(
        ILancaDexSwap.SwapData[] memory swapData,
        address receiver,
        Integration calldata integration
    ) external payable nonReentrant {
        (address fromToken, uint256 fromAmount) = (swapData[0].fromToken, swapData[0].fromAmount);
        LibLanca.transferTokenFromUser(fromToken, fromAmount);
        swapData[0].fromAmount = _collectSwapFee(fromToken, fromAmount, integration);

        bytes memory delegateCallArgs = abi.encodeWithSelector(
            ILancaDexSwap.performSwaps.selector,
            swapData,
            receiver
        );
        LibLanca.safeDelegateCall(i_dexSwap, delegateCallArgs);
    }

    /// @inheritdoc ILancaIntegration
    function withdrawIntegratorFees(address[] calldata tokens) external nonReentrant {
        address integrator = msg.sender;
        for (uint256 i; i < tokens.length; ++i) {
            address token = tokens[i];
            uint256 amount = s_integratorFeesAmountByToken[integrator][token];

            if (amount > 0) {
                delete s_integratorFeesAmountByToken[integrator][token];
                s_totalIntegratorFeesAmountByToken[token] -= amount;

                if (token == ZERO_ADDRESS) {
                    (bool success, ) = integrator.call{value: amount}("");
                    require(success, TransferFailed());
                } else {
                    IERC20(token).safeTransfer(integrator, amount);
                }

                emit IntegratorFeesWithdrawn(integrator, token, amount);
            }
        }
    }

    /* ADMIN FUNCTIONS */

    /**
     * @notice Sets the address of a DEX Router as approved or not approved to perform swaps.
     * @param router the address of the DEX Router
     * @param isApproved true if the router is approved, false if it is not approved
     */
    function setDexRouterAddress(address router, bool isApproved) external payable onlyOwner {
        require(
            router != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );
        s_routerAllowed[router] = isApproved;
    }

    function setDstLancaOrchestratorByChain(
        uint64 dstChainSelector,
        address dstOrchestrator
    ) external payable onlyOwner {
        require(
            dstChainSelector != 0 && dstChainSelector != i_chainSelector,
            InvalidChainSelector()
        );
        s_lancaOrchestratorDstByChainSelector[dstChainSelector] = dstOrchestrator;
    }

    function withdrawLancaFee(address[] calldata tokens) external nonReentrant onlyOwner {
        for (uint256 i; i < tokens.length; ++i) {
            address token = tokens[i];
            uint256 tokenBalance = IERC20(token).balanceOf(address(this));

            if (tokenBalance > 0) {
                IERC20(token).safeTransfer(
                    msg.sender,
                    tokenBalance - s_totalIntegratorFeesAmountByToken[token]
                );
            }
        }
    }

    /* INTERNAL FUNCTIONS */

    function _bridge(BridgeData memory bridgeData, Integration calldata integration) internal {
        bridgeData.amount -= _collectIntegratorFee(
            bridgeData.token,
            bridgeData.amount,
            integration
        );

        address dstLancaContract = s_lancaOrchestratorDstByChainSelector[
            bridgeData.dstChainSelector
        ];

        require(dstLancaContract != ZERO_ADDRESS, InvalidRecipient());

        bytes memory message = abi.encode(bridgeData.receiver, bridgeData.compressedDstSwapData);

        ILancaBridge.BridgeReq memory bridgeReq = ILancaBridge.BridgeReq({
            amount: bridgeData.amount,
            token: bridgeData.token,
            feeToken: i_usdc,
            receiver: dstLancaContract,
            fallbackReceiver: bridgeData.receiver,
            dstChainSelector: bridgeData.dstChainSelector,
            dstChainGasLimit: DST_CHAIN_GAS_LIMIT,
            message: message
        });

        address lancaBridge = getLancaBridge();

        IERC20(bridgeData.token).approve(lancaBridge, bridgeData.amount);
        bytes32 bridgeId = ILancaBridge(lancaBridge).bridge(bridgeReq);

        emit LancaBridgeSent(
            bridgeId,
            bridgeReq.token,
            bridgeData.amount,
            bridgeReq.receiver,
            bridgeReq.dstChainSelector
        );
    }

    function _collectSwapFee(
        address fromToken,
        uint256 fromAmount,
        Integration calldata integration
    ) internal returns (uint256) {
        fromAmount -= _getLancaFee(fromAmount);
        fromAmount -= _collectIntegratorFee(fromToken, fromAmount, integration);
        return fromAmount;
    }

    function _collectIntegratorFee(
        address token,
        uint256 amount,
        Integration calldata integration
    ) internal returns (uint256) {
        (address integrator, uint256 feeBps) = (integration.integrator, integration.feeBps);
        if (integrator == ZERO_ADDRESS || feeBps == 0) return 0;

        require(feeBps <= MAX_INTEGRATOR_FEE_BPS, InvalidIntegratorFeeBps());

        uint256 integratorFeeAmount = (amount * feeBps) / BPS_DIVISOR;

        if (integratorFeeAmount != 0) {
            s_integratorFeesAmountByToken[integrator][token] += integratorFeeAmount;
            s_totalIntegratorFeesAmountByToken[token] += integratorFeeAmount;

            emit IntegratorFeesCollected(integrator, token, integratorFeeAmount);
        }

        return integratorFeeAmount;
    }

    function _lancaBridgeReceive(LancaBridgeMessage calldata bridgeData) internal override {
        require(
            s_lancaOrchestratorDstByChainSelector[bridgeData.srcChainSelector] == bridgeData.sender,
            InvalidLancaBridgeSender()
        );

        (address receiver, bytes memory compressedDstSwapData) = abi.decode(
            bridgeData.data,
            (address, bytes)
        );

        ILancaDexSwap.SwapData[] memory swapData = _decompressSwapData(compressedDstSwapData);

        if (swapData.length == 0) {
            IERC20(bridgeData.token).safeTransfer(receiver, bridgeData.amount);
        } else {
            swapData[0].fromToken = bridgeData.token;
            swapData[0].fromAmount = bridgeData.amount;

            bytes memory delegateCallArgs = abi.encodeWithSelector(
                ILancaDexSwap.performSwaps.selector,
                swapData,
                receiver
            );

            (bool success, ) = i_dexSwap.delegatecall(delegateCallArgs);
            if (!success) {
                IERC20(bridgeData.token).safeTransfer(receiver, bridgeData.amount);
                emit DstSwapFailed(bridgeData.id);
            }
        }

        emit LancaBridgeReceived(bridgeData.id, bridgeData.token, receiver, bridgeData.amount);
    }

    /// @notice Calculates the Lanca fee for a given amount.
    /// @param amount the amount for which to calculate the fee
    /// @return the calculated Lanca fee
    function _getLancaFee(uint256 amount) internal pure returns (uint256) {
        unchecked {
            return (amount / LANCA_FEE_FACTOR);
        }
    }

    function _decompressSwapData(
        bytes memory compressedSwapData
    ) internal pure returns (ILancaDexSwap.SwapData[] memory swapData) {
        bytes memory decompressedSwapData = LibZip.cdDecompress(compressedSwapData);

        if (decompressedSwapData.length == 0) {
            return new ILancaDexSwap.SwapData[](0);
        } else {
            return abi.decode(decompressedSwapData, (ILancaDexSwap.SwapData[]));
        }
    }
}
