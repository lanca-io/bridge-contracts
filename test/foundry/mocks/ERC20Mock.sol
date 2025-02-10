// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    uint8 internal immutable i_decimals;
    constructor(string memory name, string memory symbol, uint8 decimals) ERC20(name, symbol) {
        i_decimals = decimals;
    }

    function decimals() public view override returns (uint8) {
        return i_decimals;
    }
}
