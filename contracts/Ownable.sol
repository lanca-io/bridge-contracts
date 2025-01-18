// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ZERO_ADDRESS} from "./Constants.sol";

abstract contract Ownable {
    /* IMMUTABLE VARIABLES */
    address internal immutable i_owner;

    /* ERRORS */
    /// @notice error emitted when a non-owner address call access controlled functions
    error NotOwner();
    error InvalidOwner();

    constructor(address initialOwner) {
        require(initialOwner != ZERO_ADDRESS, InvalidOwner());

        i_owner = initialOwner;
    }

    modifier onlyOwner() {
        require(msg.sender == i_owner, NotOwner());
        _;
    }
}
