// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title Interface for ILancaIntegration
/// @dev This interface provides a standard way to interact with different integrations
/// @dev Each integration should implement this interface
interface ILancaIntegration {
    /* TYPES */

    /// @notice Struct to track an integration
    /// @param integrator the address of the integrator
    /// @param feeBps the fee bps of the integrator
    struct Integration {
        address integrator;
        uint256 feeBps;
    }

    /* EVENTS */
    /// @notice Event emitted when fees are collected for an integrator
    /// @param integrator the address of the integrator
    /// @param token the address of the token
    /// @param amount the amount of the token
    event IntegratorFeesCollected(address integrator, address token, uint256 amount);

    /// @notice Event emitted when fees are withdrawn by an integrator
    /// @param integrator the address of the integrator
    /// @param token the address of the token
    /// @param amount the amount of the token
    event IntegratorFeesWithdrawn(address integrator, address token, uint256 amount);

    /* ERRORS */
    /// @notice error emitted when an invalid integrator fee bps is provided
    error InvalidIntegratorFeeBps();

    /* FUNCTIONS */

    /// @notice Withdraws the fees collected for the caller integrator
    /// @param tokens the array of tokens to withdraw the fees from
    function withdrawIntegratorFees(address[] calldata tokens) external;
}
