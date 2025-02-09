pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {DeployLancaParentPoolHarnessScript} from "../../scripts/DeployLancaParentPoolHarness.s.sol";
import {LancaParentPoolHarness} from "../../harnesses/LancaParentPoolHarness.sol";

contract LancaParentPoolTestGas is Test {
    uint256 internal constant USDC_DECIMALS = 1e6;

    DeployLancaParentPoolHarnessScript internal s_deployLancaParentPoolHarnessScript;
    LancaParentPoolHarness internal s_lancaParentPool;

    function setUp() public {
        uint256 forkId = vm.createSelectFork(vm.envString("RPC_URL_BASE"), 26000933);
        s_deployLancaParentPoolHarnessScript = new DeployLancaParentPoolHarnessScript();
        s_lancaParentPool = LancaParentPoolHarness(
            payable(s_deployLancaParentPoolHarnessScript.run(forkId))
        );
        vm.prank(s_deployLancaParentPoolHarnessScript.getDeployer());
        s_lancaParentPool.setPoolCap(60_000 * USDC_DECIMALS);
    }

    function test_startDeposit_gas() public {
        vm.pauseGasMetering();
        address depositor = makeAddr("depositor");
        uint256 amount = s_lancaParentPool.getMinDepositAmount();

        vm.startPrank(depositor);
        vm.resumeGasMetering();
        s_lancaParentPool.startDeposit(amount);
        vm.stopPrank();
    }
}
