pragma solidity 0.8.28;

import {LancaBridge} from "contracts/bridge/LancaBridge.sol";

contract LancaBridgeHarness is LancaBridge {
    constructor(
        address conceroRouter,
        address ccipRouter,
        address usdc,
        address link,
        address lancaPool,
        uint64 chainSelector
    ) LancaBridge(conceroRouter, ccipRouter, usdc, link, lancaPool, chainSelector) {}
}
