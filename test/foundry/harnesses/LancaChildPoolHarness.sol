// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaChildPool} from "contracts/pools/LancaChildPool.sol";

contract LancaChildPoolHarness is LancaChildPool {
    constructor(
        address link,
        address owner,
        address ccipRouter,
        address usdc,
        address lancaBridge,
        address[3] memory messengers
    ) LancaChildPool(link, owner, ccipRouter, usdc, lancaBridge, messengers) {}
}
