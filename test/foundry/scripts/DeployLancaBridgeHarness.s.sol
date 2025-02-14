pragma solidity 0.8.28;

import {LancaBridgeHarness} from "../harnesses/LancaBridgeHarness.sol";
import {TestHarness} from "../harnesses/TestHarness.sol";
import {LancaPoolMock} from "../mocks/LancaPoolMock.sol";
import {ConceroRouterMock} from "../mocks/ConceroRouterMock.sol";
import {DeployBase} from "./DeployBase.s.sol";

contract DeployLancaBridgeHarnessScript is DeployBase {
    function _deployImplementation() internal override returns (address) {
        address lancaPool = address(new LancaPoolMock());
        TestHarness cheats = new TestHarness();
        cheats.exposed_deal(getUsdcAddress(), lancaPool, 1_000_000e6);

        vm.startPrank(getDeployer());
        address implementation = address(
            new LancaBridgeHarness(
                address(new ConceroRouterMock()),
                getCcipRouter(),
                getUsdcAddress(),
                getLinkAddress(),
                lancaPool,
                getChainSelector(),
                7 days
            )
        );

        vm.stopPrank();

        return implementation;
    }
}
