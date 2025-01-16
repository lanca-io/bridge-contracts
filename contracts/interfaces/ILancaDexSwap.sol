// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

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
    /// @notice error emitted when the router is not allowed
    error DexRouterNotAllowed();
    /// @notice error emitted when the dexData is empty
    error EmptyDexData();
    /// @notice error emitted when a swap operation fails
    error LancaSwapFailed();
    /// @notice error emitted when the received amount is less than the minimum allowed
    /// @param amount the amount received
    error InsufficientAmount(uint256 amount);

    /* FUNCTIONS */
    function swap(
        SwapData[] calldata swapData,
        address recipient
    ) external payable returns (uint256);
}
