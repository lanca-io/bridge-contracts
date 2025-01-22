// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

library ErrorsLib {
    enum InvalidAddressType {
        zeroAddress,
        notMessenger,
        unsupportedCcipToken,
        notOwner
    }

    /// @dev Reverts when the address is invalid.
    error InvalidAddress(InvalidAddressType errorType);
}
