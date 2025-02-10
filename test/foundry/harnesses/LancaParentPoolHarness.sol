pragma solidity 0.8.28;

import {LancaParentPool} from "contracts/pools/LancaParentPool.sol";

contract LancaParentPoolHarness is LancaParentPool {
    constructor(
        TokenConfig memory tokenConfig,
        AddressConfig memory addressConfig,
        HashConfig memory hashConfig
    ) LancaParentPool(tokenConfig, addressConfig, hashConfig) {}

    function exposed_setWithdrawAmountLocked(uint256 newWithdrawAmountLocked) external {
        s_withdrawAmountLocked = newWithdrawAmountLocked;
    }

    function exposed_setChildPoolsLiqSnapshotByDepositId(
        bytes32 depositId,
        uint256 liqSnapshot
    ) external {
        s_depositRequests[depositId].childPoolsLiquiditySnapshot = liqSnapshot;
    }

    /* GETTERS */
    function exposed_getLpToken() external view returns (address) {
        return address(i_lpToken);
    }

    function exposed_getPoolChainSelectors() external view returns (uint64[] memory) {
        return s_poolChainSelectors;
    }

    function exposed_getDstPoolByChainSelector(uint64 chainSelector) external view returns (address) {
        return s_dstPoolByChainSelector[chainSelector];
    }
}
