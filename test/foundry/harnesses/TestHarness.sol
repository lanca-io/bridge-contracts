// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";

contract TestHarness is Test {
    function exposed_deal(address token, address to, uint256 amount) public {
        deal(token, to, amount);
    }
}
