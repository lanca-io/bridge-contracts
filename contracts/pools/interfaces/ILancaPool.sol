// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface ILancaPool {
    /* ERRORS */
    error WithdrawalAlreadyTriggered();
    error DistributeLiquidityRequestAlreadyProceeded();
    error InvalidCcipTxType();

    /* FUNCTIONS */

    function takeLoan(address token, uint256 amount, address receiver) external returns (uint256);
    function completeRebalancing(bytes32 id, uint256 amount) external;
}
