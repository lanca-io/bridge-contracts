// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IIntegration} from "./interfaces/IIntegration.sol";

/**
 * @title Integration
 * @dev Abstract contract that defines the integration of Lanca Orchestrator with different DEX protocols.
 * @notice This contract is used to collect the fees for Lanca and the integrators.
 * @notice The fees are represented as a percentage of the input amount.
 * @notice The fees are always taken from the first token in the swap path.
 * @notice The fees are always sent to the owner of the contract.
 * @notice The fees are always collected after the swap is successful.
 * @dev This contract is meant to be inherited by other contracts that will implement the
 *      _collectSwapFee, _collectLancaFee and _collectIntegratorFee functions.
 */
abstract contract Integration is IIntegration {
    /**
     * @notice Collects the Lanca fee and the integrator fee from the input amount.
     * @param fromToken The token to collect the fees from.
     * @param fromAmount The amount of the token to collect the fees from.
     * @param integration The integration data that contains the fee bps.
     * @return The amount of the token left after collecting the fees.
     */
    function _collectSwapFee(
        address fromToken,
        uint256 fromAmount,
        Integration calldata integration
    ) internal virtual returns (uint256);

    /**
     * @notice Collects the Lanca fee from the input amount.
     * @param token The token to collect the fees from.
     * @param amount The amount of the token to collect the fees from.
     * @return The amount of the token left after collecting the fees.
     */
    function _collectLancaFee(address token, uint256 amount) internal virtual returns (uint256);

    /**
     * @notice Collects the integrator fee from the input amount.
     * @param token The token to collect the fees from.
     * @param amount The amount of the token to collect the fees from.
     * @param integration The integration data that contains the fee bps.
     * @return The amount of the token left after collecting the fees.
     */
    function _collectIntegratorFee(
        address token,
        uint256 amount,
        Integration calldata integration
    ) internal virtual returns (uint256);
}
