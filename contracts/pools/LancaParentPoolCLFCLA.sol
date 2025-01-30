// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILancaParentPoolCLFCLA} from "../interfaces/pools/ILancaParentPoolCLFCLA.sol";
import {ILancaParentPool} from "../interfaces/pools/ILancaParentPool.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";

contract LancaParentPoolCLFCLA is ILancaParentPoolCLFCLA, FunctionsClient, AutomationCompatible {
    using SafeERC20 for IERC20;
    using ErrorsLib for *;
}
