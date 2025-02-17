// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {DeployBase} from "./DeployBase.s.sol";
import {LancaChildPoolHarness} from "../harnesses/LancaChildPoolHarness.sol";

contract DeployLancaChildPoolHarnessScript is DeployBase {
    function _deployImplementation() internal override returns (address) {
        vm.startPrank(getDeployer());

        address ccipRouter = getCcipRouter();
        address lancaBridge = makeAddr("lancaBridge");
        address owner = getDeployer();

        address[3] memory messengers = [getMessengers()[0], getMessengers()[1], getMessengers()[2]];

        address lancaChildPool = address(
            new LancaChildPoolHarness(
                owner,
                getUsdcAddress(),
                getLinkAddress(),
                lancaBridge,
                ccipRouter,
                messengers
            )
        );

        vm.stopPrank();

        return lancaChildPool;
    }
}
