// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IConceroRouter} from "concero/contracts/interfaces/IConceroRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ConceroRouterMock is IConceroRouter {
    function sendMessage(MessageRequest memory messageReq) external returns (bytes32) {
        IERC20(messageReq.feeToken).transferFrom(
            msg.sender,
            address(this),
            getFee(messageReq.dstChainSelector, messageReq.feeToken, messageReq.dstChainGasLimit)
        );

        return keccak256(abi.encode(block.number, block.prevrandao));
    }

    function getFee(uint64, address, uint32) public pure returns (uint256) {
        return 10000;
    }

    function getLinkUsdcRate() external pure returns (uint256) {
        return 100;
    }
}
