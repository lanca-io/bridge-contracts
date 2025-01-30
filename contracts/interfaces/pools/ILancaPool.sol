// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface ILancaPool {
    /* FUNCTIONS */
    function removePools(uint64 chainSelector) external payable;
    function setConceroContractSender(
        uint64 chainSelector,
        address contractAddress,
        bool isAllowed
    ) external payable;
    function distributeLiquidity(
        uint64 chainSelector,
        uint256 amountToSend,
        bytes32 distributeLiquidityRequestId
    ) external;
    function getDstTotalFeeInUsdc(uint256 amount) external pure returns (uint256);
}
