// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILancaDexSwap} from "./interfaces/ILancaDexSwap.sol";

abstract contract LancaDexSwap is ILancaDexSwap {
    /* INTERNAL FUNCTIONS */

    function _swap(
        ILancaDexSwap.SwapData[] memory swapData,
        address receiver
    ) internal virtual returns (uint256) {
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
}
