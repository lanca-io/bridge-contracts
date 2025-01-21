// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICcip} from "../interfaces/ICcip.sol";
import {ILancaPool} from "../interfaces/ILancaPool.sol";

abstract contract LancaPool is ILancaPool {
    //TODO: _ccipSend, ccipReceived and other mutual pool functions should be moved to a separate contract
    /**
     * @notice Function to distribute funds automatically right after LP deposits into the pool
     * @dev this function will only be called internally.
     */
    function _ccipSend(
        uint64 chainSelector,
        uint256 amount,
        ICcip.CcipTxType _ccipTxType
    ) internal virtual returns (bytes32);
}
