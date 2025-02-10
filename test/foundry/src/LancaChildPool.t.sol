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
    }

    function test_setPools() public {
        address pool = makeAddr("pool");
        uint64 chainSelector = 1;

        vm.prank(s_deployChildPoolHarnessScript.getDeployer());
        s_lancaChildPool.setPools(chainSelector, pool);

        vm.assertEq(s_lancaChildPool.exposed_getDstPoolByChainSelector(chainSelector), pool);
        vm.assertEq(s_lancaChildPool.exposed_getPoolChainSelectors()[0], chainSelector);
    }

    /* REVERTS */

    /* SET POOLS */

    function test_setPoolsNotOwner_revert() public {
        address pool = makeAddr("pool");
        uint64 chainSelector = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notOwner
            )
        );
        s_lancaChildPool.setPools(chainSelector, pool);
    }

    function test_setPoolsTheSamePool_revert() public {
        uint64 chainSelector = 1;
        address pool = makeAddr("pool");

        vm.startPrank(s_deployChildPoolHarnessScript.getDeployer());
        s_lancaChildPool.setPools(chainSelector, pool);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.sameAddress
            )
        );
        s_lancaChildPool.setPools(chainSelector, pool);

        vm.stopPrank();
    }

    function test_setPoolsInvalidAddress_revert() public {
        address poolAddress = makeAddr("pool");
        uint64 chainSelector = 2;
        vm.startPrank(s_deployChildPoolHarnessScript.getDeployer());

        s_lancaChildPool.setPools(chainSelector, poolAddress);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.zeroAddress
            )
        );
        s_lancaChildPool.setPools(chainSelector, address(0));

        vm.stopPrank();
    }

    function test_removePoolsNotOwner_revert() public {
        uint64 chainSelector = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notOwner
            )
        );
        s_lancaChildPool.removePools(chainSelector);
    }

    function test_distributeLiquidityNotMessenger_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notMessenger
            )
        );
        s_lancaChildPool.distributeLiquidity(0, 0, bytes32(0));
    }

    function test_ccipSendToPoolNotMessenger_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notMessenger
            )
        );
        s_lancaChildPool.ccipSendToPool(0, 0, bytes32(0));
    }

    function test_liquidatePoolNotMessenger_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notMessenger
            )
        );
        s_lancaChildPool.liquidatePool(bytes32(0));
    }
}
