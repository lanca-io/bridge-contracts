// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LancaOrchestratorStorageSetters} from "./LancaOrchestratorStorageSetters.sol";
import {ILancaBridge} from "./interfaces/ILancaBridge.sol";
import {ILancaIntegration} from "./interfaces/ILancaIntegration.sol";
import {ILancaDexSwap} from "./interfaces/ILancaDexSwap.sol";
import {LancaDexSwap} from "./LancaDexSwap.sol";
import {ICcip} from "./interfaces/ICcip.sol";
import {LancaLib} from "./libraries/LancaLib.sol";
import {ZERO_ADDRESS} from "./Constants.sol";
import {LancaIntegration} from "./LancaIntegration.sol";
import {LancaBridgeClient} from "./LancaBridgeClient/LancaBridgeClient.sol";
import {LibZip} from "solady/src/utils/LibZip.sol";

contract LancaOrchestrator is LancaDexSwap, LancaIntegration, LancaBridgeClient {
    using SafeERC20 for IERC20;

    /* TYPES */

    /* CONSTANTS */
    uint8 internal constant MAX_TOKEN_PATH_LENGTH = 5;
    uint16 internal constant MAX_INTEGRATOR_FEE_BPS = 1000;
    uint16 internal constant BPS_DIVISOR = 10000;
    uint24 internal constant DST_CHAIN_GAS_LIMIT = 1_000_000;

    /* IMMUTABLES */
    address internal immutable i_usdc;
    address internal immutable i_addressThis;

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
        // @dev TODO: remove it, it is wrong!
        i_addressThis = address(this);
    }

    /* MODIFIERS */
    modifier validateSwapData(ILancaDexSwap.SwapData[] memory swapData) {
        _validateSwapData(swapData);
        _;
    }

    modifier validateBridgeData(ILancaBridge.BridgeData memory bridgeData) {
        require(bridgeData.amount != 0 && bridgeData.receiver != ZERO_ADDRESS, InvalidBridgeData());
        _;
    }

    /* EXTERNAL FUNCTIONS */

    /**
     * @notice Performs a token swap followed by a cross-chain bridge operation.
     * @param bridgeData The data required for the bridging process.
     * @param swapData The list of swap operations to perform before bridging.
     * @param compressedDstSwapData Additional swap data for the destination chain.
     * @param integration Integration details for fee calculation.
     */
    function swapAndBridge(
        ILancaBridge.BridgeData memory bridgeData,
        ILancaDexSwap.SwapData[] memory swapData,
        bytes calldata compressedDstSwapData,
        Integration calldata integration
    ) external payable nonReentrant validateSwapData(swapData) validateBridgeData(bridgeData) {
        address usdc = LancaLib.getUSDCAddressByChain(ICcip.CcipToken.usdc);
        require(swapData[swapData.length - 1].toToken == usdc, InvalidSwapData());

        LancaLib.transferTokenFromUser(swapData[0].fromToken, swapData[0].fromAmount);

        bridgeData.amount = _swap(swapData, i_addressThis);

        bridge(
            bridgeData.token,
            bridgeData.amount,
            bridgeData.receiver,
            bridgeData.dstChainSelector,
            compressedDstSwapData,
            integration
        );
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
        address token,
        uint256 amount,
        address receiver,
        uint64 dstChainSelector,
        bytes calldata compressedDstSwapData,
        Integration calldata integration
    ) public nonReentrant {
        require(token == i_usdc, InvalidBridgeToken());

        IERC20(token).safeTransferFrom(msg.sender, i_addressThis, amount);
        amount -= _collectIntegratorFee(token, amount, integration);

        address dstLancaContract = s_lancaOrchestratorDstByChainSelector[dstChainSelector];
        bytes memory message = abi.encode(receiver, compressedDstSwapData);

        ILancaBridge.BridgeData memory bridgeData = ILancaBridge.BridgeData({
            amount: amount,
            token: token,
            feeToken: i_usdc,
            receiver: dstLancaContract,
            dstChainSelector: dstChainSelector,
            dstChainGasLimit: DST_CHAIN_GAS_LIMIT,
            message: compressedDstSwapData
        });

        ILancaBridge(getLancaBridge()).bridge(bridgeData);
    }

    /// @inheritdoc ILancaDexSwap
    function swap(
        ILancaDexSwap.SwapData[] memory swapData,
        address receiver,
        Integration calldata integration
    ) public payable nonReentrant validateSwapData(swapData) {
        (address fromToken, uint256 fromAmount) = (swapData[0].fromToken, swapData[0].fromAmount);
        LancaLib.transferTokenFromUser(fromToken, fromAmount);
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
            s_integratorFeesAmountByToken[i_addressThis][token] += lancaFee;
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

    function _lancaBridgeReceive(LancaBridgeData calldata bridgeData) internal override {
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
            _swap(swapData, receiver);
        }

        emit LancaBridgeReceived(bridgeData.id, bridgeData.token, receiver, bridgeData.amount);
    }

    function _decompressSwapData(
        bytes memory compressedSwapData
    ) internal pure returns (SwapData[] memory swapData) {
        bytes memory decompressedSwapData = LibZip.cdDecompress(compressedSwapData);

        if (decompressedSwapData.length == 0) {
            return new SwapData[](0);
        } else {
            return abi.decode(decompressedSwapData, (SwapData[]));
        }
    }

    function _validateSwapData(SwapData[] memory swapData) internal pure {
        require(
            swapData.length != 0 &&
                swapData.length <= MAX_TOKEN_PATH_LENGTH &&
                swapData[0].fromAmount != 0,
            InvalidSwapData()
        );
    }
}
