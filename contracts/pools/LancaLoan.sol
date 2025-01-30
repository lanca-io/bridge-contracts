// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaPoolStorage} from "../storages/LancaPoolStorage.sol";
import {LibErrors} from "../libraries/LibErrors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ZERO_ADDRESS} from "../Constants.sol";

abstract contract LancaLoan is LancaPoolStorage {
    using SafeERC20 for IERC20;

    function takeLoan(address token, uint256 amount, address receiver) external payable {
        require(
            receiver != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );
        require(
            token == address(i_USDC),
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.notUsdcToken)
        );
        IERC20(token).safeTransfer(receiver, amount);
        s_loansInUse += amount;
    }
}
