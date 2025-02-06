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

    function exposed_getMaxDstChainGasLimit() public pure returns (uint24) {
        return MAX_DST_CHAIN_GAS_LIMIT;
    }

    function exposed_getBatchedTxThreshold() public pure returns (uint256) {
        return BATCHED_TX_THRESHOLD;
    }
}
