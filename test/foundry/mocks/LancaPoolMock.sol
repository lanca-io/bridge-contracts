// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LancaPoolMock {
    function takeLoan(address token, uint256 amount, address receiver) external {
        IERC20(token).transfer(receiver, amount);
    }
}
