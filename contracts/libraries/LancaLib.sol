// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ZERO_ADDRESS} from "../Constants.sol";

library LancaLib {
    using SafeERC20 for IERC20;

    /* ERRORS */
    /// @dev Reverts when transfer data is invalid (e.g., zero amount or recipient address).
    error InvalidTransferData();

    /// @dev Reverts when the token transfer fails.
    error TransferFailed();

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
}
