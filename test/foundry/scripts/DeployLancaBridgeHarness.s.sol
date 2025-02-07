pragma solidity 0.8.28;

import {DeployLancaBridgeScriptBase} from "./DeployLancaBridgeBase.s.sol";
import {LancaBridgeHarness} from "../harnesses/LancaBridgeHarness.sol";
import {TestHarness} from "../harnesses/TestHarness.sol";
import {LancaPoolMock} from "../mocks/LancaPoolMock.sol";
import {ConceroRouterMock} from "../mocks/ConceroRouterMock.sol";

contract DeployLancaBridgeHarnessScript is DeployLancaBridgeScriptBase {
    function _deployLancaBridge() internal override {
        address lancaPool = address(new LancaPoolMock());
        TestHarness cheats = new TestHarness();
        cheats.exposed_deal(getUsdcAddress(), lancaPool, 1_000_000e6);

        vm.startPrank(getDeployer());
        s_lancaBridge = address(
            new LancaBridgeHarness(
                address(new ConceroRouterMock()),
                getCcipRouter(),
                getUsdcAddress(),
                getLinkAddress(),
                lancaPool,
                getChainSelector()
            )
        );

        vm.stopPrank();
    }
}
