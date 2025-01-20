// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface ILancaPool {
    /* FUNCTIONS */
    function takeLoan(address token, uint256 amount, address receiver) external payable;
}
