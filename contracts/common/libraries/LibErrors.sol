// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

library LibErrors {
    enum InvalidAddressType {
        zeroAddress,
        unsupportedCcipToken,
        notUsdcToken,
        sameAddress
    }

    enum UnauthorizedType {
        notLancaBridge,
        notMessenger,
        notOwner,
        notAutomationForwarder,
        notLpProvider,
        notAllowedSender
    }

    /// @dev Reverts when the address is invalid.
    error InvalidAddress(InvalidAddressType errorType);
    error Unauthorized(UnauthorizedType errorType);
    error InvalidChainSelector();
}
