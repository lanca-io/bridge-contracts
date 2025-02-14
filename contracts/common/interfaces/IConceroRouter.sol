// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IConceroRouter {
    struct MessageRequest {
        address feeToken;
        address receiver;
        uint64 dstChainSelector;
        uint32 dstChainGasLimit;
        bytes data;
    }

    function sendMessage(MessageRequest memory messageReq) external returns (bytes32);
    function getFeeInUsdc(uint64 dstChainSelector) external view returns (uint256);
}
