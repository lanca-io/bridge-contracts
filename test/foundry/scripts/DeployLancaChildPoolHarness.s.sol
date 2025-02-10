// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {DeployBase} from "./DeployBase.s.sol";

contract DeployLancaChildPoolHarnessScript is DeployBase {
    function _deployImplementation() internal override returns (address) {
        vm.startPrank(getDeployer());

        address link = getLinkAddress();
        address usdc = getUsdcAddress();
        address ccipRouter = getCcipRouter();
        address clfRouter = getClfRouter();
        address lancaBridge = makeAddr("lancaBridge");
        address owner = getDeployer();

        address lancaChildPool = address(
            new LancaChildPoolHarness(link, owner, ccipRouter, usdc, lancaBridge)
        );

        vm.stopPrank();

        return lancaChildPool;
    }
}
