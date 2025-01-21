// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

abstract contract LancaPoolStorage {
    ///@notice array of chain IDS of Pools to receive Liquidity through `ccipSend` function
    uint64[] internal s_poolChainSelectors;

    ///@notice Mapping to keep track of allowed pool senders
    mapping(uint64 chainSelector => mapping(address conceroContract => bool isAllowed))
        public s_isSenderContractAllowed;

    /// @notice Mapping to keep track of Liquidity Providers withdraw requests
    mapping(bytes32 => bool) public s_distributeLiquidityRequestProcessed;
}
