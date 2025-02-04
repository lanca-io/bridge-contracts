// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IConceroRouter} from "contracts/common/interfaces/IConceroRouter.sol";

contract ConceroRouterMock is IConceroRouter {
    function sendMessage(MessageRequest memory messageReq) external returns (bytes32) {
        return keccak256(abi.encode(block.number));
    }

    function getFee(uint64 dstChainSelector) external view returns (uint256) {
        return 10000;
    }
}
