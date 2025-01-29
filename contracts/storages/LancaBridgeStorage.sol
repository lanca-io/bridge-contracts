// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

abstract contract LancaBridgeStorage {
    /// @notice Variable to store the Link to USDC latest rate
    uint256 internal s_latestLinkUsdcRate;

    mapping(uint64 chainSelector => address lancaBridge) internal s_lancaBridgeContractsByChain;
    mapping(uint64 dstChainSelector => bytes32[] bridgeTxIds)
        internal s_pendingSettlementIdsByDstChain;
    mapping(bytes32 conceroMessageId => bytes32 bridgeDataHash)
        internal s_pendingSettlementTxHashById;
    mapping(uint64 dstChainSelector => uint256 amount)
        internal s_pendingSettlementTxAmountByDstChain;
    mapping(uint64 dstChainSelector => uint256 lastCcipFeeInLink) internal s_lastCcipFeeInLink;
    mapping(address sender => bool isAllowed) internal s_isConceroMessageSenderAllowed;
    mapping(uint64 srcChainSelector => bool isAllowed) internal s_isConceroMessageSrcChainAllowed;

    /* GETTERS */
    function getPendingSettlementIdsByDstChain(
        uint64 dstChainSelector
    ) external view returns (bytes32[] memory) {
        return s_pendingSettlementIdsByDstChain[dstChainSelector];
    }

    function getPendingSettlementTxHashById(
        bytes32 conceroMessageId
    ) external view returns (bytes32) {
        return s_pendingSettlementTxHashById[conceroMessageId];
    }

    function getPendingSettlementTxAmountByDstChain(
        uint64 dstChainSelector
    ) external view returns (uint256) {
        return s_pendingSettlementTxAmountByDstChain[dstChainSelector];
    }

    function isConceroMessageSenderAllowed(address sender) external view returns (bool) {
        return s_isConceroMessageSenderAllowed[sender];
    }

    function isConceroMessageSrcChainAllowed(uint64 srcChainSelector) external view returns (bool) {
        return s_isConceroMessageSrcChainAllowed[srcChainSelector];
    }
}
