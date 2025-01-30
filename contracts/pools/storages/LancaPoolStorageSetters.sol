// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaPoolStorage} from "./LancaPoolStorage.sol";
import {LibErrors} from "../../common/libraries/LibErrors.sol";

abstract contract LancaPoolStorageSetters is LancaPoolStorage {
    /* MODIFIERS */
    /**
     * @notice CCIP Modifier to check Chains And senders
     * @param chainSelector Id of the source chain of the message
     * @param sender address of the sender contract
     */
    modifier onlyAllowListedSenderOfChainSelector(uint64 chainSelector, address sender) {
        require(
            s_isSenderContractAllowed[chainSelector][sender],
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.unauthorized)
        );
        _;
    }
}
