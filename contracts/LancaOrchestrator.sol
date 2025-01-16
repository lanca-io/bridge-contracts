// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaOrchestratorStorage} from "./storages/LancaOrchestratorStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILancaBridge} from "./interfaces/ILancaBridge.sol";
import {ILancaDexSwap} from "./interfaces/ILancaDexSwap.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LancaLib} from "./libraries/LancaLib.sol";
import {ZERO_ADDRESS} from "./Constants.sol";

contract LancaOrchestrator is LancaOrchestratorStorage, ILancaDexSwap {
    using SafeERC20 for IERC20;

    /* TYPES */

    struct Integration {
        address integrator;
        uint256 feeBps;
    }

    /* ERRORS */
    error InvalidIntegratorFeeBps();
    error InvalidBridgeToken();

    /* CONSTANTS */
    uint16 internal constant MAX_INTEGRATOR_FEE_BPS = 1000;
    uint16 internal constant BPS_DIVISOR = 10000;
    uint24 internal constant DST_CHAIN_GAS_LIMIT = 1_000_000;

    /* IMMUTABLES */
    address internal immutable i_usdc;
    address internal immutable i_lancaBridge;
    address internal immutable i_addressThis;

    /* EVENTS */
    event IntegratorFeesCollected(address integrator, address token, uint256 amount);

    constructor(address usdc, address lancaBridge) {
        i_usdc = usdc;
        i_lancaBridge = lancaBridge;
        i_addressThis = address(this);
    }

    /* FUNCTIONS */

    function bridge(
        address token,
        uint256 amount,
        address receiver,
        uint64 dstChainSelector,
        bytes calldata compressedDstSwapData,
        Integration calldata integration
    ) external nonReentrant {
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
        address recipient
    ) external payable nonReentrant returns (uint256) {
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
        require(balanceAfter != 0, InvalidDexData());

        uint256 dstTokenReceived = balanceAfter - dstTokenProxyInitialBalance;

        if (recipient != i_addressThis) {
            LancaLib.transferTokenToUser(recipient, dstToken, dstTokenReceived);
        }

        emit LancaSwap(
            swapData[0].fromToken,
            dstToken,
            swapData[0].fromAmount,
            dstTokenReceived,
            recipient
        );

        return dstTokenReceived;
    }

    function swapAndBridge(
        ILancaBridge.BridgeData calldata bridgeData,
        ILancaDexSwap.SwapData[] memory swapData,
        bytes calldata compressedDstSwapData,
        Integration calldata integration
    ) external payable nonReentrant {}

    /* INTERNAL FUNCTIONS */

    function _collectIntegratorFee(
        address token,
        uint256 amount,
        Integration calldata integration
    ) internal returns (uint256) {
        (address integrator, uint256 feeBps) = (integration.integrator, integration.feeBps);
        if (integrator == ZERO_ADDRESS) return 0;
        require(feeBps <= MAX_INTEGRATOR_FEE_BPS, InvalidIntegratorFeeBps());

        uint256 integratorFeeAmount = (amount * feeBps) / BPS_DIVISOR;
        if (integratorFeeAmount == 0) return 0;

        s_integratorFeesAmountByToken[integrator][token] += integratorFeeAmount;
        //        s_totalIntegratorFeesAmountByToken[token] += integratorFeeAmount;

        emit IntegratorFeesCollected(integrator, token, integratorFeeAmount);
        return integratorFeeAmount;
    }

    /**
     * @notice Perform a swap on a SwapData
     * @param swapData the SwapData to perform the swap
     */
    function _performSwap(ILancaDexSwap.SwapData memory swapData) internal {
        bytes memory dexCallData = swapData.dexCallData;
        require(dexCallData.length != 0, EmptyDexData());

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
}
