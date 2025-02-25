// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILancaIntegration} from "./ILancaIntegration.sol";

interface ILancaDexSwap {
    /* TYPES */

    /// @notice Lanca Struct to track DEX Data
    /// @param dexRouter address of the DEX Router
    /// @param fromToken address of the token to be swapped
    /// @param fromAmount amount of token to be swapped
    /// @param toToken address of the token to be received
    /// @param toAmount amount of token to be received
    /// @param toAmountMin minimum amount of token to be received
    /// @param dexCallData encoded data for the DEX
    struct SwapData {
        address dexRouter;
        address fromToken;
        uint256 fromAmount;
        address toToken;
        uint256 toAmount;
        uint256 toAmountMin;
        bytes dexCallData;
    }

    /* EVENTS */
    /// @notice Event emitted when a swap is executed
    event LancaSwap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 toAmount,
        address receiver
    );

    /* ERRORS */

    error DexRouterNotAllowed();
    error EmptySwapData();
    error InvalidSwapData();
    error LancaSwapFailed();
    error InvalidTokenPath();
    error InsufficientAmount(uint256 amount);

    function performSwaps(
        SwapData[] memory swapData,
        address receiver
    ) external payable returns (uint256);
}
