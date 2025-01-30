// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LancaOrchestratorStorage} from "./LancaOrchestratorStorage.sol";
import {ZERO_ADDRESS} from "../../common/Constants.sol";
import {LancaOwnable} from "../../common/LancaOwnable.sol";
import {LibErrors} from "../../common/libraries/LibErrors.sol";

abstract contract LancaOrchestratorStorageSetters is LancaOrchestratorStorage, LancaOwnable {
    constructor(address owner) LancaOwnable(owner) {}

    /**
     * @notice Sets the address of a DEX Router as approved or not approved to perform swaps.
     * @param router the address of the DEX Router
     * @param isApproved true if the router is approved, false if it is not approved
     */
    function setDexRouterAddress(address router, bool isApproved) external payable onlyOwner {
        require(
            router != ZERO_ADDRESS,
            LibErrors.InvalidAddress(LibErrors.InvalidAddressType.zeroAddress)
        );
        s_routerAllowed[router] = isApproved;
    }
}
