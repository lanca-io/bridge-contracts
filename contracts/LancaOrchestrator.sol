// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LancaOrchestratorStorage} from "./storages/LancaOrchestratorStorage.sol";
import {LancaOrchestratorStorageSetters} from "./LancaOrchestratorStorageSetters.sol";
import {ILancaBridge} from "./interfaces/ILancaBridge.sol";
import {ILancaDexSwap} from "./interfaces/ILancaDexSwap.sol";
import {ICcip} from "./interfaces/ICcip.sol";
import {LancaLib} from "./libraries/LancaLib.sol";
import {Ownable} from "./Ownable.sol";
import {ZERO_ADDRESS} from "./Constants.sol";

contract LancaOrchestrator is LancaOrchestratorStorageSetters, ILancaDexSwap {
    using SafeERC20 for IERC20;

    /* TYPES */

    struct Integration {
        address integrator;
        uint256 feeBps;
    }

    /* CONSTANTS */
    uint8 internal constant MAX_TOKEN_PATH_LENGTH = 5;
    uint16 internal constant MAX_INTEGRATOR_FEE_BPS = 1000;
    uint16 internal constant LANCA_FEE_FACTOR = 1000;
    uint16 internal constant BPS_DIVISOR = 10000;
    uint24 internal constant DST_CHAIN_GAS_LIMIT = 1_000_000;

    /* IMMUTABLES */
    address internal immutable i_usdc;
    address internal immutable i_lancaBridge;
    address internal immutable i_addressThis;

    /* EVENTS */
    event ConceroFeesCollected(address token, uint256 amount);
    event IntegratorFeesCollected(address integrator, address token, uint256 amount);
    event IntegratorFeesWithdrawn(address integrator, address token, uint256 amount);

    /* ERRORS */
    error InvalidIntegratorFeeBps();
    error InvalidBridgeToken();
    error InvalidBridgeData();
    error InvalidRecipient();

    constructor(address usdc, address lancaBridge) LancaOrchestratorStorageSetters(msg.sender) {
        i_usdc = usdc;
        i_lancaBridge = lancaBridge;
        i_addressThis = address(this);
    }

    /* MODIFIERS */
    modifier validateSwapData(ILancaDexSwap.SwapData[] memory swapData) {
        require(
            swapData.length != 0 &&
                swapData.length <= MAX_TOKEN_PATH_LENGTH &&
                swapData[0].fromAmount != 0,
            InvalidSwapData()
        );
        _;
    }

    modifier validateBridgeData(ILancaBridge.BridgeData memory bridgeData) {
        require(bridgeData.amount != 0 && bridgeData.receiver != ZERO_ADDRESS, InvalidBridgeData());
        _;
    }

    /* EXTERNAL FUNCTIONS */

    function swapAndBridge(
        ILancaBridge.BridgeData memory bridgeData,
        ILancaDexSwap.SwapData[] memory swapData,
        bytes calldata compressedDstSwapData,
        Integration calldata integration
    ) external payable nonReentrant validateSwapData(swapData) validateBridgeData(bridgeData) {
        address usdc = LancaLib.getUSDCAddressByChain(ICcip.CcipToken.usdc);
        require(swapData[swapData.length - 1].toToken == usdc, InvalidSwapData());

        LancaLib.transferTokenFromUser(swapData[0].fromToken, swapData[0].fromAmount);

        uint256 amountReceivedFromSwap = _swap(swapData, i_addressThis);

        /// @custom:fee do we need this? - NO
        bridgeData.amount =
            amountReceivedFromSwap -
            _collectIntegratorFee(usdc, amountReceivedFromSwap, integration);

        bridge(
            bridgeData.token,
            bridgeData.amount,
            bridgeData.receiver,
            bridgeData.dstChainSelector,
            compressedDstSwapData,
            integration
        );
    }

    /// @custom:reentrant it looks like we don't need this
    /// @notice Withdraws all the collected fees in the specified tokens for the current integrator.
    /// @param tokens the tokens to withdraw the fees from
    function withdrawIntegratorFees(address[] calldata tokens) external nonReentrant {
        address integrator = msg.sender;
        for (uint256 i; i < tokens.length; ++i) {
            address token = tokens[i];
            uint256 amount = s_integratorFeesAmountByToken[integrator][token];

            if (amount > 0) {
                delete s_integratorFeesAmountByToken[integrator][token];
                //s_totalIntegratorFeesAmountByToken[token] -= amount;

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

    /**
     * @notice Function to allow Concero Team to withdraw fees
     * @param recipient the recipient address
     * @param tokens array of token addresses to withdraw
     */
    // @dev TODO mb remove this function
    function withdrawLancaFees(
        address recipient,
        address[] calldata tokens
    ) external payable nonReentrant onlyOwner {
        require(recipient != ZERO_ADDRESS, InvalidRecipient());

        address usdc = LancaLib.getUSDCAddressByChain(ICcip.CcipToken.usdc);

        for (uint256 i; i < tokens.length; ++i) {
            address token = tokens[i];
            uint256 balance = LancaLib.getBalance(token, i_addressThis);
            uint256 integratorFees = s_integratorFeesAmountByToken[i_addressThis][token];
            uint256 availableBalance = balance - integratorFees;

            if (token == usdc) {
                uint256 batchedReserves;
                /// @custom:TODO: move to getSupportedChainSelectors, which should use immutable variables passed to infraCommon
                uint64[SUPPORTED_CHAINS_COUNT] memory chainSelectors = [
                    CHAIN_SELECTOR_ARBITRUM,
                    CHAIN_SELECTOR_BASE,
                    CHAIN_SELECTOR_POLYGON,
                    CHAIN_SELECTOR_AVALANCHE,
                    CHAIN_SELECTOR_ETHEREUM,
                    CHAIN_SELECTOR_OPTIMISM
                ];
                for (uint256 j; j < SUPPORTED_CHAINS_COUNT; ++j) {
                    batchedReserves += s_pendingSettlementTxAmountByDstChain[chainSelectors[j]];
                }
                availableBalance -= batchedReserves;
            }

            LancaLib.transferTokenToUser(recipient, token, availableBalance);
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

        ILancaBridge(i_lancaBridge).bridge(bridgeData);
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

    function _swap(
        ILancaDexSwap.SwapData[] memory swapData,
        address receiver
    ) internal returns (uint256) {
        uint256 swapDataLength = swapData.length;
        uint256 lastSwapStepIndex = swapDataLength - 1;
        address dstToken = swapData[lastSwapStepIndex].toToken;
        uint256 dstTokenProxyInitialBalance = LancaLib.getBalance(dstToken, i_addressThis);
        uint256 balanceAfter;

        for (uint256 i; i < swapDataLength; ++i) {
            uint256 balanceBefore = LancaLib.getBalance(swapData[i].toToken, i_addressThis);

            _performSwap(swapData[i]);

            balanceAfter = LancaLib.getBalance(swapData[i].toToken, i_addressThis);
            uint256 tokenReceived = balanceAfter - balanceBefore;
            require(tokenReceived >= swapData[i].toAmountMin, InsufficientAmount(tokenReceived));

            if (i < lastSwapStepIndex) {
                require(swapData[i].toToken == swapData[i + 1].fromToken, InvalidTokenPath());
                swapData[i + 1].fromAmount = tokenReceived;
            }
        }

        // @dev check if swapDataLength is 0 and there were no swaps
        require(balanceAfter != 0, InvalidSwapData());

        uint256 dstTokenReceived = balanceAfter - dstTokenProxyInitialBalance;

        if (receiver != i_addressThis) {
            LancaLib.transferTokenToUser(receiver, dstToken, dstTokenReceived);
        }

        emit LancaSwap(
            swapData[0].fromToken,
            dstToken,
            swapData[0].fromAmount,
            dstTokenReceived,
            receiver
        );

        return dstTokenReceived;
    }

    function _collectSwapFee(
        address fromToken,
        uint256 fromAmount,
        Integration calldata integration
    ) internal returns (uint256) {
        fromAmount -= _collectLancaFee(fromToken, fromAmount);
        fromAmount -= _collectIntegratorFee(fromToken, fromAmount, integration);
        return fromAmount;
    }

    function _collectLancaFee(address token, uint256 amount) internal returns (uint256) {
        uint256 lancaFee = _getLancaFee(amount);
        if (lancaFee != 0) {
            // @dev TODO: pass token token address as well
            s_integratorFeesAmountByToken[i_addressThis][token] += lancaFee;
            // @dev TODO: remove to save gas
            emit LancaFeesCollected(token, lancaFee);
        }
        return lancaFee;
    }

    function _getLancaFee(uint256 amount) internal pure returns (uint256) {
        unchecked {
            return (amount / LANCA_FEE_FACTOR);
        }
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
            emit IntegratorFeesCollected(integrator, token, integratorFeeAmount);
        }

        return integratorFeeAmount;
    }

    /**
     * @notice Perform a swap on a SwapData
     * @param swapData the SwapData to perform the swap
     */
    function _performSwap(ILancaDexSwap.SwapData memory swapData) internal {
        bytes memory dexCallData = swapData.dexCallData;
        require(dexCallData.length != 0, EmptySwapData());

        address dexRouter = swapData.dexRouter;
        require(s_routerAllowed[dexRouter], DexRouterNotAllowed());

        uint256 fromAmount = swapData.fromAmount;
        address fromToken = swapData.fromToken;
        bool isFromNative = fromToken == ZERO_ADDRESS;

        bool success;
        if (!isFromNative) {
            IERC20(fromToken).safeIncreaseAllowance(dexRouter, fromAmount);
            (success, ) = dexRouter.call(dexCallData);
        } else {
            (success, ) = dexRouter.call{value: fromAmount}(dexCallData);
        }

        require(success, LancaSwapFailed());
    }

    /* PRIVATE FUNCTIONS */
}
