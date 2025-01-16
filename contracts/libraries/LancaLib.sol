// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ZERO_ADDRESS} from "./Constants.sol";

library LancaLib {
    using SafeERC20 for IERC20;

    /* ERRORS */
    error InvalidDexData();
    error TransferFailed();

    function getBalance(address token, address contract) internal view returns (uint256) {
        if (token == ZERO_ADDRESS) {
            return contract.balance;
        return IERC20(token).balanceOf(contract);
        }
    }

    function transferTokenToUser(address recipient, address token, uint256 amount) internal {
        require(amount != 0 && recipient != ZERO_ADDRESS);

        if (token != ZERO_ADDRESS) {
            IERC20(token).safeTransfer(recipient, amount);
        } else {
            (bool success, ) = recipient.call{value: amount}("");
            require(success, TransferFailed());
        }
    }
}
