// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

abstract contract LancaPoolCommonStorage {
    uint256 internal s_loansInUse;

    uint64[] internal s_poolChainSelectors;

    mapping(uint64 chainSelector => address pool) internal s_dstPoolByChainSelector;

    mapping(uint64 chainSelector => mapping(address conceroContract => bool isAllowed))
        internal s_isSenderContractAllowed;

    mapping(bytes32 => bool) internal s_distributeLiquidityRequestProcessed;

    /* STORAGE GAP */
    /// @notice gap to reserve storage in the contract for future variable additions
    uint256[50] private __gap;

    /* GETTERS */
    function getUsdcLoansInUse() external view returns (uint256) {
        return s_loansInUse;
    }
}
