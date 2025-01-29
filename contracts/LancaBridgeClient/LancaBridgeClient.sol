// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILancaBridgeClient} from "./Interfaces/ILancaBridgeClient.sol";

error InvalidLancaBridge(address sender);
error InvalidLancaBridgeContract();

abstract contract LancaBridgeClient is ILancaBridgeClient {
    address private immutable i_lancaBridge;

    constructor(address lancaBridge) {
        if (lancaBridge == address(0) || lancaBridge.code.length == 0) {
            revert InvalidLancaBridgeContract();
        }

        i_lancaBridge = lancaBridge;
    }

    function lancaBridgeReceive(LancaBridgeData calldata message) external {
        if (msg.sender != i_lancaBridge) {
            revert InvalidLancaBridge(msg.sender);
        }

        _lancaBridgeReceive(message);
    }

    function getLancaBridge() public view returns (address) {
        return i_lancaBridge;
    }

    function _lancaBridgeReceive(LancaBridgeData calldata message) internal virtual;
}
