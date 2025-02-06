// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {DeployLancaParentPoolScriptBase} from "./DeployLancaParentPoolBase.s.sol";
import {LancaParentPoolMock} from "../mocks/LancaParentPoolMock.sol";
import {LibLanca} from "contracts/common/libraries/LibLanca.sol";
import {DeployLancaBridgeHarnessScript} from "../scripts/DeployLancaBridgeHarness.s.sol";

contract DeployLancaParentPoolHarnessScript is DeployLancaParentPoolScriptBase {
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
            lpToken: makeAddr("lpToken")
        });

        DeployLancaBridgeHarnessScript deployLancaBridge = new DeployLancaBridgeHarnessScript();
        LibLanca.Addr memory addr = LibLanca.Addr({
            ccipRouter: getCcipRouter(),
            automationForwarder: makeAddr("automation forwarder"),
            parentPoolProxy: makeAddr("parent pool proxy"),
            owner: getDeployer(),
            lancaParentPoolCLFCLA: makeAddr("lancaParentPoolCLFCLA"),
            lancaBridge: makeAddr("lancaBridge")
        });

        address[3] memory messengers = [
            makeAddr("messenger 0"),
            makeAddr("messenger 1"),
            makeAddr("messenger 2")
        ];

        LibLanca.Hash memory hash = LibLanca.Hash({
            collectLiquidityJs: bytes32(0),
            distributeLiquidityJs: bytes32(0)
        });
        s_lancaParentPool = address(new LancaParentPoolMock(token, addr, clf, hash, messengers));

        vm.stopPrank();
    }
}
