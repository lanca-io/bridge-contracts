pragma solidity 0.8.28;

import {DeployLancaBridgeScriptBase} from "./DeployLancaBridgeBase.s.sol";
import {LancaBridgeHarness} from "../harnesses/LancaBridgeHarness.sol";
import {LancaPoolMock} from "../mocks/LancaPoolMock.sol";
import {ConceroRouterMock} from "../mocks/ConceroRouterMock.sol";

contract DeployLancaBridgeHarnessScript is DeployLancaBridgeScriptBase {
    function _deployLancaBridge() internal override {
        vm.startPrank(getDeployer());
        s_lancaBridge = address(
            new LancaBridgeHarness(
                address(new ConceroRouterMock()),
                getCcipRouter(),
                getUsdcAddress(),
                getLinkAddress(),
                address(new LancaPoolMock()),
                getChainSelector()
            )
        );

        vm.stopPrank();
    }
}
