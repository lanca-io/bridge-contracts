// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title Pause Dummy
/// @dev This contract is a dummy that reverts all calls. It is used in the tests
/// to simulate a paused contract.
contract PauseDummy {
    /// @notice Reverts when the contract is paused.
    error Paused();

    fallback() external payable {
        revert Paused();
    }
    receive() external payable {
        revert Paused();
    }
}
