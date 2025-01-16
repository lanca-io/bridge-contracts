// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICcip} from "../interfaces/ICcip.sol";
import {ZERO_ADDRESS, USDC_AVALANCHE, USDC_ARBITRUM, USDC_BASE, USDC_POLYGON, USDC_AVALANCHE, USDC_OPTIMISM, USDC_ETHEREUM} from "../Constants.sol";

library LancaLib {
    using SafeERC20 for IERC20;

    /* ERRORS */
    /// @dev Reverts when transfer data is invalid (e.g., zero amount or recipient address).
    error InvalidTransferData();

    /// @notice Reverts when the provided amount is invalid (e.g., zero amount).
    /// @dev This error is typically thrown when the amount of tokens to transfer is invalid.
    error InvalidAmount();

    /// @dev Reverts when the token transfer fails.
    error TransferFailed();

    /// @dev Reverts when the provided chain ID is not supported.
    /// @param chainId The ID of the chain that is not supported.
    error ChainNotSupported(uint256 chainId);

    /// @dev Reverts when the token type is not supported.
    /// @param tokenType The unsupported token type.
    error TokenTypeNotSupported(ICcip.CcipToken tokenType);

    /// @dev Reverts when the token transfer is attempted to the null address.
    error TransferToNullAddress();

    /// @dev Reverts when the token is not an ERC20 token.
    error TokenIsNotERC20();

    /**
     * @dev Returns the balance of the token for the contractAddress.
     * @param token the token to check the balance of
     * @param contractAddress the address to check the balance of
     * @return balance the balance of the token
     */
    function getBalance(address token, address contractAddress) internal view returns (uint256) {
        if (token == ZERO_ADDRESS) {
            return contractAddress.balance;
        }
        return IERC20(token).balanceOf(contractAddress);
    }

    /**
     * @dev Transfers the amount of token to the recipient.
     * @param recipient the address to send the token to
     * @param token the token to transfer
     * @param amount the amount of token to transfer
     */
    function transferTokenToUser(address recipient, address token, uint256 amount) internal {
        require(amount != 0 && recipient != ZERO_ADDRESS, InvalidTransferData());

        if (token != ZERO_ADDRESS) {
            IERC20(token).safeTransfer(recipient, amount);
        } else {
            (bool success, ) = recipient.call{value: amount}("");
            require(success, TransferFailed());
        }
    }

    function transferFromERC20(address token, address from, address to, uint256 amount) internal {
        require(token != ZERO_ADDRESS, TokenIsNotERC20());
        require(to != ZERO_ADDRESS, TransferToNullAddress());
        IERC20(token).safeTransferFrom(from, to, amount);
    }

    function transferTokenFromUser(address fromToken, uint256 fromAmount) internal {
        if (fromToken != ZERO_ADDRESS) {
            transferFromERC20(fromToken, msg.sender, address(this), fromAmount);
        } else {
            require(fromAmount == msg.value, InvalidAmount());
        }
    }

    function getUSDCAddressByChain(
        ICcip.CcipToken tokenType
    ) internal view returns (address usdcAddress) {
        require(tokenType == ICcip.CcipToken.usdc, TokenTypeNotSupported(tokenType));
        uint256 chainId = block.chainid;

        if (chainId == CHAIN_ID_AVALANCHE) {
            return USDC_AVALANCHE;
        }
        if (chainId == CHAIN_ID_ARBITRUM) {
            return USDC_ARBITRUM;
        }
        if (chainId == CHAIN_ID_BASE) {
            return USDC_BASE;
        }
        if (chainId == CHAIN_ID_POLYGON) {
            return USDC_POLYGON;
        }
        if (chainId == CHAIN_ID_OPTIMISM) {
            return USDC_OPTIMISM;
        }
        if (chainId == CHAIN_ID_ETHEREUM) {
            return USDC_ETHEREUM;
        }

        revert ChainNotSupported(chainId);
    }
}
