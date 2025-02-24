// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILancaPool} from "contracts/pools/interfaces/ILancaPool.sol";

contract LancaPoolMock is ILancaPool {
    uint256 internal constant PRECISION_HANDLER = 1e10;
    uint256 internal constant LP_FEE_FACTOR = 1000;

    IERC20 internal i_usdc;

    constructor(address usdc) {
        i_usdc = IERC20(usdc);
    }

    function takeLoan(address token, uint256 amount, address receiver) external returns (uint256) {
        uint256 loanAmount = amount - getDstTotalFeeInUsdc(amount);
        IERC20(token).transfer(receiver, loanAmount);
        return loanAmount;
    }

    function completeRebalancing(bytes32 /*id*/, uint256 amount) external {
        i_usdc.transferFrom(msg.sender, address(this), amount);
    }

    function getDstTotalFeeInUsdc(uint256 amount) public pure returns (uint256) {
        return (amount * PRECISION_HANDLER) / LP_FEE_FACTOR / PRECISION_HANDLER;
    }
}
