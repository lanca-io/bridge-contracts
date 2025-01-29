// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ZERO_ADDRESS} from "./Constants.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";

abstract contract LancaOwnable {
    using ErrorsLib for *;

    /* IMMUTABLE VARIABLES */
    address internal immutable i_owner;

    constructor(address initialOwner) {
        require(
            initialOwner != ZERO_ADDRESS,
            ErrorsLib.InvalidAddress(ErrorsLib.InvalidAddressType.zeroAddress)
        );

        i_owner = initialOwner;
    }

    modifier onlyOwner() {
        require(
            msg.sender == i_owner,
            ErrorsLib.InvalidAddress(ErrorsLib.InvalidAddressType.notOwner)
        );
        _;
    }
}
