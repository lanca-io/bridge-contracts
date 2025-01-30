// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICcip} from "../common/interfaces/ICcip.sol";
import {LibErrors} from "./LibErrors.sol";
import {ZERO_ADDRESS, USDC_AVALANCHE, USDC_ARBITRUM, USDC_BASE, USDC_POLYGON, USDC_AVALANCHE, USDC_OPTIMISM, USDC_ETHEREUM, CHAIN_ID_AVALANCHE, CHAIN_ID_ARBITRUM, CHAIN_ID_BASE, CHAIN_ID_POLYGON, CHAIN_ID_OPTIMISM, CHAIN_ID_ETHEREUM} from "../Constants.sol";

library LibLanca {
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

    /// @dev Reverts when the delegate call failed.
    /// @param data The data that was passed to the delegate call.
    error UnableToCompleteDelegateCall(bytes data);

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
        require(
            token != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );
        require(
            to != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );
        IERC20(token).safeTransferFrom(from, to, amount);
    }

    function transferERC20(address token, uint256 amount, address recipient) internal {
        require(
            token != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );
        require(
            recipient != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );
        IERC20(token).safeTransfer(recipient, amount);
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
        require(
            tokenType == ICcip.CcipToken.usdc,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.unsupportedCcipToken)
        );
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

    function safeDelegateCall(address target, bytes memory args) internal returns (bytes memory) {
        require(
            target != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );
        (bool success, bytes memory response) = target.delegatecall(args);
        require(success, UnableToCompleteDelegateCall(args));
        return response;
    }
}
