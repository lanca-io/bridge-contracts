// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LibLanca} from "contracts/common/libraries/LibLanca.sol";
import {LancaParentPool} from "contracts/pools/LancaParentPool.sol";

contract LancaParentPoolMock is LancaParentPool {
    constructor(
        LibLanca.Token memory token,
        LibLanca.Addr memory addr,
        LibLanca.Clf memory clf,
        LibLanca.Hash memory hash,
        address[3] memory messengers
    ) LancaParentPool(token, addr, clf, hash, messengers) {}

    /* SETTERS */

    function setLiquidityCap(uint256 newLiquidityCap) external {
        s_liquidityCap = newLiquidityCap;
    }

    function setDepositFeeAmount(uint256 newDepositFeeAmount) external {
        s_depositFeeAmount = newDepositFeeAmount;
    }

    function setWithdrawAmountLocked(uint256 newWithdrawAmountLocked) external {
        s_withdrawAmountLocked = newWithdrawAmountLocked;
    }

    function getParentPoolCLFCLA() external view returns (address) {
        return address(i_lancaParentPoolCLFCLA);
    }
}
