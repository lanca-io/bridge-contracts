// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface ILancaBridge {
    /* TYPES */

    struct BridgeData {
        uint256 amount;
        address token;
        address feeToken;
        address receiver;
        uint64 dstChainSelector;
        uint32 dstChainGasLimit;
        bytes message;
    }

    /* FUNCTIONS */
    function bridge(BridgeData calldata bridgeData) external;
}
