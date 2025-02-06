// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaBridgeClient} from "contracts/LancaBridgeClient/LancaBridgeClient.sol";

contract LancaBridgeClientMock is LancaBridgeClient {
    event LancaBridgeReceived(bytes32 indexed id, address token, uint256 amount);

    constructor(address lancaBridge) LancaBridgeClient(lancaBridge) {}

    function _lancaBridgeReceive(LancaBridgeMessage calldata lancaBridgeMessage) internal override {
        emit LancaBridgeReceived(
            lancaBridgeMessage.id,
            lancaBridgeMessage.token,
            lancaBridgeMessage.amount
        );
    }
}
