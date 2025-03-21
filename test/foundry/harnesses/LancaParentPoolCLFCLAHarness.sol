// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ILancaParentPool} from "contracts/pools/interfaces/ILancaParentPool.sol";
import {LancaParentPoolCLFCLA} from "contracts/pools/LancaParentPoolCLFCLA.sol";

contract LancaParentPoolCLFCLAHarness is LancaParentPoolCLFCLA {
    constructor(
        address lpToken,
        address usdc,
        address clfRouter,
        uint64 clfSubId,
        bytes32 clfDonId,
        uint8 clfSecretsSlotId,
        uint64 clfSecretsVersion,
        bytes32 collectLiquidityJsCodeHash,
        bytes32 ethersJsHash,
        uint256 withdrawalCooldownSeconds
    ) LancaParentPoolCLFCLA(
            lpToken,
            usdc,
            clfRouter,
            clfSubId,
            clfDonId,
            clfSecretsSlotId,
            clfSecretsVersion,
            collectLiquidityJsCodeHash,
            ethersJsHash,
            withdrawalCooldownSeconds
    ) {}
}
