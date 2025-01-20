// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./Interfaces/ILancaBridgeClient.sol";

error InvalidLancaBridgeRouter(address sender);

abstract contract LancaBridgeClient is ILancaBridgeClient {
    address private immutable i_lancaBridgeRouter;

    modifier onlyRouter() {
        if (msg.sender != i_lancaBridgeRouter) {
            revert InvalidLancaBridgeRouter(msg.sender);
        }
        _;
    }

    constructor(address router) {
        if (router == address(0)) {
            revert InvalidLancaBridgeRouter(router);
        }

        if (router.code.length == 0) {
            revert InvalidLancaBridgeRouter(router);
        }

        i_lancaBridgeRouter = router;
    }

    function conceroReceive(LancaBridgeData calldata message) external onlyRouter {
        _conceroReceive(message);
    }

    function getConceroRouter() public view returns (address) {
        return i_lancaBridgeRouter;
    }

    function _conceroReceive(LancaBridgeData calldata message) internal virtual;
}
