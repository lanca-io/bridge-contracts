// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface ILancaBridgeClient {
    struct LancaBridgeMessage {
        bytes32 id;
        address sender;
        address token;
        uint256 amount;
        uint64 srcChainSelector;
        bytes data;
    }

    function lancaBridgeReceive(LancaBridgeMessage calldata message) external;
}
