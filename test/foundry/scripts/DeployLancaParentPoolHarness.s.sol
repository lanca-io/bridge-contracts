// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {DeployLancaParentPoolScriptBase} from "./DeployLancaParentPoolBase.s.sol";
import {LancaParentPool} from "contracts/pools/LancaParentPool.sol";
import {LibLanca} from "contracts/common/libraries/LibLanca.sol";
import {DeployLancaBridgeHarnessScript} from "../scripts/DeployLancaBridgeHarness.s.sol";

contract DeployLancaParentPoolHarness is DeployLancaParentPoolScriptBase {
    function _deployLancaParentPool() internal override {
        vm.startPrank(getDeployer());

        LibLanca.Clf memory clf = LibLanca.Clf({
            router: getClfRouter(),
            subId: getCLfSubId(),
            donId: getCLfDonId(),
            donHostedSecretsSlotId: getDonHostedSecretsSlotId(),
            donHostedSecretsVersion: getDonHostedSecretsVersion()
        });

        LibLanca.Token memory token = LibLanca.Token({
            link: getLinkAddress(),
            usdc: getUsdcAddress(),
            lpToken: getLpTokenAddress()
        });

        DeployLancaBridgeHarnessScript deployLancaBridge = new DeployLancaBridgeHarnessScript();
        deployLancaBridge.LibLanca.Addr memory addr = LibLanca.Addr({
            ccipRouter: getCcipRouter(),
            automationForwarder: makeAddr("automation forwarder"),
            parentPoolProxy: getParentPoolProxy(),
            owner: getDeployer(),
            lancaParentPoolCLFCLA: makeAddr("lancaParentPoolCLFCLA"),
            lancaBridge: getLancaBridge()
        });

        s_lancaParentPool = address(new LancaParentPool(token, addr, clf));

        vm.stopPrank();
    }
}
