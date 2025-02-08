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
}
