// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LancaOrchestratorStorageSetters} from "./storages/LancaOrchestratorStorageSetters.sol";
import {ILancaBridge} from "../bridge/interfaces/ILancaBridge.sol";
import {ILancaIntegration} from "./interfaces/ILancaIntegration.sol";
import {ILancaDexSwap} from "./interfaces/ILancaDexSwap.sol";
import {LancaDexSwap} from "./LancaDexSwap.sol";
import {ICcip} from "../common/interfaces/ICcip.sol";
import {LibLanca} from "../common/libraries/LibLanca.sol";
import {ZERO_ADDRESS} from "../common/Constants.sol";
import {LancaIntegration} from "./LancaIntegration.sol";
import {LancaBridgeClient} from "../LancaBridgeClient/LancaBridgeClient.sol";

contract LancaOrchestrator is LancaDexSwap, LancaIntegration, LancaBridgeClient {
    using SafeERC20 for IERC20;

    /* TYPES */

    struct BridgeData {
        address token;
        address receiver;
        uint256 amount;
        uint64 dstChainSelector;
        bytes data;
    }

    /* CONSTANTS */
    uint16 internal constant MAX_INTEGRATOR_FEE_BPS = 1_000;
    uint16 internal constant BPS_DIVISOR = 10_000;
    uint24 internal constant DST_CHAIN_GAS_LIMIT = 1_000_000;

    /* IMMUTABLES */
    address internal immutable i_usdc;

    /* ERRORS */
    error InvalidBridgeToken();
    error InvalidBridgeData();
    error InvalidRecipient();
    error TransferFailed();
    error InvalidLancaBridgeSender();
    error InvalidLancaBridgeSrcChain();

    /* EVENTS */
    event LancaBridgeReceived(bytes32 indexed id, address token, address receiver, uint256 amount);

    /**
     * @dev Constructor for the LancaOrchestrator contract.
     * @param usdc The address of the USDC token.
     * @param lancaBridge The address of the LancaBridge contract.
     */
    constructor(
        address usdc,
        address lancaBridge
    ) LancaDexSwap(msg.sender) LancaBridgeClient(lancaBridge) {
        i_usdc = usdc;
    }

    /* MODIFIERS */
    modifier validateSwapData(ILancaDexSwap.SwapData[] memory swapData) {
        _validateSwapData(swapData);
        _;
    }

    modifier validateBridgeData(BridgeData memory bridgeData) {
        require(bridgeData.amount != 0 && bridgeData.receiver != ZERO_ADDRESS, InvalidBridgeData());
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
    ) external payable nonReentrant validateSwapData(swapData) validateBridgeData(bridgeData) {
        address usdc = LibLanca.getUSDCAddressByChain(ICcip.CcipToken.usdc);
        require(swapData[swapData.length - 1].toToken == usdc, InvalidSwapData());

        LibLanca.transferTokenFromUser(swapData[0].fromToken, swapData[0].fromAmount);

        bridgeData.amount = _swap(swapData, address(this));

        // @dev: we call nonReentrant 2 times, mb it is a problem
        bridge(bridgeData, integration);
    }

    /// @inheritdoc ILancaIntegration
    function withdrawIntegratorFees(address[] calldata tokens) external override nonReentrant {
        address integrator = msg.sender;
        for (uint256 i; i < tokens.length; ++i) {
            address token = tokens[i];
            uint256 amount = s_integratorFeesAmountByToken[integrator][token];

            if (amount > 0) {
                delete s_integratorFeesAmountByToken[integrator][token];

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

    /* PUBLIC FUNCTIONS */

    function bridge(
        BridgeData memory bridgeData,
        Integration calldata integration
    ) public nonReentrant {
        require(bridgeData.token == i_usdc, InvalidBridgeToken());

        IERC20(bridgeData.token).safeTransferFrom(msg.sender, address(this), bridgeData.amount);
        bridgeData.amount -= _collectIntegratorFee(
            bridgeData.token,
            bridgeData.amount,
            integration
        );

        address dstLancaContract = s_lancaOrchestratorDstByChainSelector[
            bridgeData.dstChainSelector
        ];
        bytes memory message = abi.encode(bridgeData.receiver, bridgeData.data);

        ILancaBridge.BridgeReq memory bridgeReq = ILancaBridge.BridgeReq({
            amount: bridgeData.amount,
            token: bridgeData.token,
            feeToken: i_usdc,
            receiver: dstLancaContract,
            fallbackReceiver: msg.sender,
            dstChainSelector: bridgeData.dstChainSelector,
            dstChainGasLimit: DST_CHAIN_GAS_LIMIT,
            message: bridgeData.data
        });

        ILancaBridge(getLancaBridge()).bridge(bridgeReq);
    }

    /// @inheritdoc ILancaDexSwap
    function swap(
        ILancaDexSwap.SwapData[] memory swapData,
        address receiver,
        Integration calldata integration
    ) public payable nonReentrant validateSwapData(swapData) {
        (address fromToken, uint256 fromAmount) = (swapData[0].fromToken, swapData[0].fromAmount);
        LibLanca.transferTokenFromUser(fromToken, fromAmount);
        swapData[0].fromAmount = _collectSwapFee(fromToken, fromAmount, integration);
        _swap(swapData, receiver);
    }

    /* INTERNAL FUNCTIONS */

    /// @inheritdoc LancaIntegration
    function _collectSwapFee(
        address fromToken,
        uint256 fromAmount,
        Integration calldata integration
    ) internal override returns (uint256) {
        fromAmount -= _collectLancaFee(fromToken, fromAmount);
        fromAmount -= _collectIntegratorFee(fromToken, fromAmount, integration);
        return fromAmount;
    }

    /// @inheritdoc LancaIntegration
    function _collectLancaFee(address token, uint256 amount) internal override returns (uint256) {
        uint256 lancaFee = _getLancaFee(amount);
        if (lancaFee != 0) {
            s_integratorFeesAmountByToken[address(this)][token] += lancaFee;
        }
        return lancaFee;
    }

    /// @inheritdoc LancaIntegration
    function _collectIntegratorFee(
        address token,
        uint256 amount,
        Integration calldata integration
    ) internal override returns (uint256) {
        (address integrator, uint256 feeBps) = (integration.integrator, integration.feeBps);
        if (integrator == ZERO_ADDRESS || feeBps == 0) return 0;

        require(feeBps <= MAX_INTEGRATOR_FEE_BPS, InvalidIntegratorFeeBps());

        uint256 integratorFeeAmount = (amount * feeBps) / BPS_DIVISOR;

        if (integratorFeeAmount != 0) {
            s_integratorFeesAmountByToken[integrator][token] += integratorFeeAmount;
            emit IntegratorFeesCollected(integrator, token, integratorFeeAmount);
        }

        return integratorFeeAmount;
    }

    function _lancaBridgeReceive(LancaBridgeMessage calldata bridgeData) internal override {
        // @dev: mb it is possible to pack it into one sload
        require(s_isLancaBridgeSenderAllowed[bridgeData.sender], InvalidLancaBridgeSender());
        require(
            s_isLancaBridgeSrcChainAllowed[bridgeData.srcChainSelector],
            InvalidLancaBridgeSrcChain()
        );

        (address receiver, bytes memory compressedDstSwapData) = abi.decode(
            bridgeData.data,
            (address, bytes)
        );

        SwapData[] memory swapData = _decompressSwapData(compressedDstSwapData);

        if (swapData.length == 0) {
            IERC20(bridgeData.token).safeTransfer(receiver, bridgeData.amount);
        } else {
            swapData[0].fromToken = bridgeData.token;
            swapData[0].fromAmount = bridgeData.amount;

            _validateSwapData(swapData);
            // @dev TODO: add try catch block
            _swap(swapData, receiver);
        }

        emit LancaBridgeReceived(bridgeData.id, bridgeData.token, receiver, bridgeData.amount);
    }

    /// @notice Calculates the Lanca fee for a given amount.
    /// @param amount the amount for which to calculate the fee
    /// @return the calculated Lanca fee
    function _getLancaFee(uint256 amount) internal pure virtual returns (uint256) {
        unchecked {
            return (amount / LANCA_FEE_FACTOR);
        }
    }
}
