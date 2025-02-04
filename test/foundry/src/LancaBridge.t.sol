pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {DeployLancaBridgeHarnessScript} from "../scripts/DeployLancaBridgeHarness.s.sol";
import {LancaBridgeHarness} from "../harnesses/LancaBridgeHarness.sol";
import {console} from "forge-std/src/console.sol";

contract LancaBridgeTest is Test {
    DeployLancaBridgeHarnessScript internal s_deployLancaBridgeHarnessScript =
        new DeployLancaBridgeHarnessScript();
    uint256 internal s_baseForkId = vm.createSelectFork(vm.envString("RPC_URL_BASE"));
    LancaBridgeHarness internal s_lancaBridge =
        LancaBridgeHarness(s_deployLancaBridgeHarnessScript.run());

    function test_run() public {
        console.log(address(s_lancaBridge));
    }
}
