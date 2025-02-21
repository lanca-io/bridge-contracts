// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICcip} from "../interfaces/ICcip.sol";
import {LibErrors} from "./LibErrors.sol";
import {ZERO_ADDRESS} from "../Constants.sol";

library LibLanca {
    using SafeERC20 for IERC20;

    /* ERRORS */

    error InvalidTransferData();
    error InvalidAmount();
    error TransferFailed();
    error ChainNotSupported(uint256 chainId);
    error TokenTypeNotSupported(ICcip.CcipToken tokenType);
    error UnableToCompleteDelegateCall(bytes data);

    /* CONSTANTS */
    uint256 internal constant USDC_DECIMALS = 1e6;
    uint256 internal constant STANDARD_TOKEN_DECIMALS = 1 ether;

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

    function safeDelegateCall(address target, bytes memory args) internal returns (bytes memory) {
        require(
            target != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );
        (bool success, bytes memory response) = target.delegatecall(args);

        if (!success) {
            assembly {
                let response_size := mload(response)
                let response_ptr := add(response, 32)
                revert(response_ptr, response_size)
            }
        }

        return response;
    }

    function toUsdcDecimals(uint256 amount) internal pure returns (uint256) {
        return (amount * USDC_DECIMALS) / STANDARD_TOKEN_DECIMALS;
    }
}
