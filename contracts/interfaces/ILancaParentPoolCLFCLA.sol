// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */

interface ILancaParentPoolCLFCLA {
    /// @notice Event emitted when a new withdrawal request is made.
    event WithdrawalRequestInitiated(
        bytes32 indexed requestId,
        address lpAddress,
        uint256 triggedAtTimestamp
    );

    function sendCLFRequest(bytes[] memory args) external returns (bytes32);

    function calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256);

    function fulfillRequestWrapper(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) external;

    function retryPerformWithdrawalRequest() external;
}

interface IParentPoolCLFCLAViewDelegate {
    function calculateWithdrawableAmountViaDelegateCall(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256);

    function checkUpkeepViaDelegate() external view returns (bool, bytes memory);
}
