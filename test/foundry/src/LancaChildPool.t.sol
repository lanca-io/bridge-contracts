// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {LancaChildPoolHarness} from "../harnesses/LancaChildPoolHarness.sol";
import {DeployLancaChildPoolHarnessScript} from "../scripts/DeployLancaChildPoolHarness.s.sol";
import {LibErrors} from "contracts/common/libraries/LibErrors.sol";

contract LancaChildPoolTest is Test {
    DeployLancaChildPoolHarnessScript internal s_deployChildPoolHarnessScript;
    LancaChildPoolHarness internal s_lancaChildPool;

    address internal s_usdc = vm.envAddress("USDC_BASE");

    function setUp() public {
        uint256 forkId = vm.createSelectFork(vm.envString("RPC_URL_BASE"), 26000933);
        s_deployChildPoolHarnessScript = new DeployLancaChildPoolHarnessScript();
        s_lancaChildPool = LancaChildPoolHarness(
            payable(s_deployChildPoolHarnessScript.run(forkId))
        );
        //vm.prank(s_deployChildPoolHarnessScript.getDeployer());
        //s_lancaChildPool.setPoolCap(60_000 * USDC_DECIMALS);
    }

    /* REVERTS */
    function test_removePoolsNotOwner_revert() public {
        uint64 chainSelector = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.notOwner
            )
        );
        s_lancaChildPool.removePools(chainSelector);
    }

    function test_distributeLiquidityNotMessenger_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.notMessenger
            )
        );
        s_lancaChildPool.distributeLiquidity(0, 0, bytes32(0));
    }

    function test_ccipSendToPoolNotMessenger_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.notMessenger
            )
        );
        s_lancaChildPool.ccipSendToPool(0, 0, bytes32(0));
    }

    function test_liquidatePoolNotMessenger_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.notMessenger
            )
        );
        s_lancaChildPool.liquidatePool(bytes32(0));
    }
}
