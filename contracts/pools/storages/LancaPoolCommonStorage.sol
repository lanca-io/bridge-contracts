// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

abstract contract LancaPoolCommonStorage {
    uint256 internal s_loansInUse;

    uint64[] internal s_poolChainSelectors;

    mapping(uint64 chainSelector => address pool) internal s_dstPoolByChainSelector;

    mapping(bytes32 => bool) internal s_distributeLiquidityRequestProcessed;

    /* STORAGE GAP */
    /// @notice gap to reserve storage in the contract for future variable additions
    uint256[50] private __gap;

    /* GETTERS */
    function getUsdcLoansInUse() public view returns (uint256) {
        return s_loansInUse;
    }

    function getDstPoolByChainSelector(uint64 chainSelector) public view returns (address) {
        return s_dstPoolByChainSelector[chainSelector];
    }
}
