// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ZERO_ADDRESS} from "./Constants.sol";
import {LibErrors} from "./libraries/LibErrors.sol";

abstract contract LancaOwnable {
    /* IMMUTABLE VARIABLES */
    address internal immutable i_owner;

    constructor(address initialOwner) {
        require(
            initialOwner != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );

        i_owner = initialOwner;
    }

    modifier onlyOwner() {
        require(
            msg.sender == i_owner,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.notOwner)
        );
        _;
    }
}
