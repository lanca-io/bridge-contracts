// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILancaDexSwap} from "./interfaces/ILancaDexSwap.sol";
import {LibLanca} from "../common/libraries/LibLanca.sol";
import {ZERO_ADDRESS} from "../common/Constants.sol";
import {LibZip} from "solady/src/utils/LibZip.sol";
import {LancaOrchestratorStorage} from "./storages/LancaOrchestratorStorage.sol";

abstract contract LancaDexSwap is LancaOrchestratorStorage, ILancaDexSwap {
    using SafeERC20 for IERC20;

    /* CONSTANTS */
    uint16 internal constant LANCA_FEE_FACTOR = 1000;
    uint8 internal constant MAX_SWAPS_LENGTH = 5;

    /* INTERNAL FUNCTIONS */

    /**
     * @notice Perform a swap on a list of SwapData, with the first SwapData.fromToken being the input token and the last SwapData.toToken being the output token.
     * @param swapData the list of SwapData to perform the swap in order
     * @param receiver the address to send the output token to
     * @return dstTokenReceived the amount of token received after the swap
     */
    function _swap(
        ILancaDexSwap.SwapData[] memory swapData,
        address receiver
    ) internal virtual returns (uint256) {
        address addressThis = address(this);
        uint256 swapDataLength = swapData.length;
        uint256 lastSwapStepIndex = swapDataLength - 1;
        address dstToken = swapData[lastSwapStepIndex].toToken;
        uint256 dstTokenProxyInitialBalance = LibLanca.getBalance(dstToken, addressThis);
        uint256 balanceAfter;

        for (uint256 i; i < swapDataLength; ++i) {
            uint256 balanceBefore = LibLanca.getBalance(swapData[i].toToken, addressThis);

            _performSwap(swapData[i]);

            balanceAfter = LibLanca.getBalance(swapData[i].toToken, addressThis);
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

        if (receiver != addressThis) {
            LibLanca.transferTokenToUser(receiver, dstToken, dstTokenReceived);
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

    /**
     * @notice Perform a swap on a SwapData
     * @param swapData the SwapData to perform the swap
     */
    function _performSwap(ILancaDexSwap.SwapData memory swapData) internal virtual {
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
                swapData.length <= MAX_SWAPS_LENGTH &&
                swapData[0].fromAmount != 0,
            InvalidSwapData()
        );
    }
}
