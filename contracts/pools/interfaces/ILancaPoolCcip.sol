// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface ILancaPoolCcip {
    // @dev TODO: mb replace it with only one argument (id)
    event CCIPReceived(
        bytes32 indexed ccipMessageId,
        uint64 srcChainSelector,
        address sender,
        address token,
        uint256 amount
    );
}
