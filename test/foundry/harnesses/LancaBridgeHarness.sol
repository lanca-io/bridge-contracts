pragma solidity 0.8.28;

import {LancaBridge} from "contracts/bridge/LancaBridge.sol";

contract LancaBridgeHarness is LancaBridge {
    constructor(
        address conceroRouter,
        address ccipRouter,
        address usdc,
        address link,
        address lancaPool,
        uint64 chainSelector,
        uint256 batchedTxThreshold
    )
        LancaBridge(
            conceroRouter,
            ccipRouter,
            usdc,
            link,
            lancaPool,
            chainSelector,
            batchedTxThreshold
        )
    {}

    /* SETTERS */
    function exposed_setIsBridgeProcessed(bytes32 messageId) public {
        s_isBridgeProcessed[messageId] = true;
    }

    function exposed_getMaxDstChainGasLimit() public pure returns (uint24) {
        return MAX_DST_CHAIN_GAS_LIMIT;
    }

    function exposed_getBatchedTxThreshold() public view returns (uint256) {
        return i_batchedTxThreshold;
    }

    function exposed_getLancaPool() public view returns (address) {
        return address(i_lancaPool);
    }

    function exposed_isBridgeProcessed(bytes32 messageId) public view returns (bool) {
        return s_isBridgeProcessed[messageId];
    }
}
