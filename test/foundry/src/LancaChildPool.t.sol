// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {LancaChildPoolHarness} from "../harnesses/LancaChildPoolHarness.sol";
import {DeployLancaChildPoolHarnessScript} from "../scripts/DeployLancaChildPoolHarness.s.sol";
import {LibErrors} from "contracts/common/libraries/LibErrors.sol";
import {ZERO_ADDRESS} from "contracts/common/Constants.sol";
import {ILancaPool} from "contracts/pools/interfaces/ILancaPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILancaChildPool} from "contracts/pools/interfaces/ILancaChildPool.sol";
import {console} from "forge-std/src/Console.sol";

contract LancaChildPoolTest is Test {
    uint256 internal constant USDC_DECIMALS = 1e6;

    DeployLancaChildPoolHarnessScript internal s_deployChildPoolHarnessScript;
    LancaChildPoolHarness internal s_lancaChildPool;

    address internal s_usdc;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_URL_BASE"), 26000933);
        s_deployChildPoolHarnessScript = new DeployLancaChildPoolHarnessScript();
        s_lancaChildPool = LancaChildPoolHarness(payable(s_deployChildPoolHarnessScript.run()));
        s_usdc = s_lancaChildPool.exposed_getUsdcToken();
    }

    function test_setDstPool() public {
        address pool = makeAddr("pool");
        uint64 chainSelector = 1;

        vm.prank(s_deployChildPoolHarnessScript.getDeployer());
        s_lancaChildPool.setDstPool(chainSelector, pool);

        vm.assertEq(s_lancaChildPool.exposed_getDstPoolByChainSelector(chainSelector), pool);
        vm.assertEq(s_lancaChildPool.exposed_getPoolChainSelectors()[0], chainSelector);
        vm.assertEq(s_lancaChildPool.getDstPoolByChainSelector(chainSelector), pool);
    }

    function test_getDstTotalFeeInUsdc() public view {
        uint256 amount0 = 1 ether;
        uint256 amount1 = 2 ether;
        uint256 fee0 = s_lancaChildPool.getDstTotalFeeInUsdc(amount0);
        uint256 fee1 = s_lancaChildPool.getDstTotalFeeInUsdc(amount1);

        vm.assertGt(fee0, 0);
        vm.assertGt(fee1, 0);
        vm.assertGt(fee1 - fee0, 0);
    }

    function test_getUsdcLoansInUse() public {
        uint256 beforeLoans = s_lancaChildPool.getUsdcLoansInUse();
        vm.assertEq(beforeLoans, 0);

        deal(s_usdc, address(s_lancaChildPool), 1000 * USDC_DECIMALS);
        address receiver = makeAddr("receiver");
        uint256 amount = 100 * USDC_DECIMALS;
        vm.prank(s_lancaChildPool.exposed_getLancaBridge());
        uint256 afterLoans = s_lancaChildPool.takeLoan(s_usdc, amount, receiver);
        vm.assertGt(afterLoans, 0);
        uint256 fee = amount - afterLoans;
        vm.assertGt(fee, 0);
    }

    function test_removePools() public {
        uint64 chainSelector = 1;
        address pool = makeAddr("pool");

        vm.startPrank(s_deployChildPoolHarnessScript.getDeployer());
        s_lancaChildPool.setDstPool(chainSelector, pool);

        s_lancaChildPool.removePools(chainSelector);

        vm.assertEq(s_lancaChildPool.exposed_getPoolChainSelectors().length, 0);
        vm.assertEq(
            s_lancaChildPool.exposed_getDstPoolByChainSelector(chainSelector),
            ZERO_ADDRESS
        );
    }

    function test_takeLoan() public {
        deal(s_usdc, address(s_lancaChildPool), 1000 * USDC_DECIMALS);
        address receiver = makeAddr("receiver");
        uint256 amount = 100 * USDC_DECIMALS;

        vm.prank(s_lancaChildPool.exposed_getLancaBridge());
        uint256 loanAmount = s_lancaChildPool.takeLoan(s_usdc, amount, receiver);

        vm.assertEq(IERC20(s_usdc).balanceOf(receiver), loanAmount);
        vm.assertEq(s_lancaChildPool.exposed_getLoansInUse(), amount);
    }

    function test_completeRebalancing() public {
        deal(s_usdc, address(s_lancaChildPool.exposed_getLancaBridge()), 100 * USDC_DECIMALS);
        deal(s_usdc, address(s_lancaChildPool), 1000 * USDC_DECIMALS);
        uint256 amount = 100 * USDC_DECIMALS;
        address receiver = makeAddr("receiver");

        vm.prank(s_lancaChildPool.exposed_getLancaBridge());
        s_lancaChildPool.takeLoan(s_usdc, amount, receiver);
        uint256 beforeBal = s_lancaChildPool.getUsdcLoansInUse();
        vm.assertEq(beforeBal, amount);

        vm.startPrank(s_lancaChildPool.exposed_getLancaBridge());
        IERC20(s_usdc).approve(address(s_lancaChildPool), amount);
        bytes32 anyValue = 0x0000000000000000000000000000000000000000000000000000000000000001;
        amount = 22 * USDC_DECIMALS;

        s_lancaChildPool.completeRebalancing(anyValue, amount);
        uint256 afterBal = s_lancaChildPool.getUsdcLoansInUse();
        vm.assertEq(afterBal, beforeBal - amount);
        vm.stopPrank();
    }

    /* REVERTS */
    function test_setDstPoolNotOwner_revert() public {
        address pool = makeAddr("pool");
        uint64 chainSelector = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notOwner
            )
        );
        s_lancaChildPool.setDstPool(chainSelector, pool);
    }

    function test_useNotOnlyLancaBridge_revert() public {
        deal(s_usdc, address(s_lancaChildPool), 1000 * USDC_DECIMALS);
        address receiver = makeAddr("receiver");
        uint256 amount = 100 * USDC_DECIMALS;

        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notLancaBridge
            )
        );
        s_lancaChildPool.takeLoan(s_usdc, amount, receiver);

        bytes32 anyValue = 0x0000000000000000000000000000000000000000000000000000000000000001;
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notLancaBridge
            )
        );
        s_lancaChildPool.completeRebalancing(anyValue, amount);
    }
    /* SET POOLS */

    function test_setDstPoolInvalidAddress_revert() public {
        address poolAddress = makeAddr("pool");
        uint64 chainSelector = 2;
        vm.startPrank(s_deployChildPoolHarnessScript.getDeployer());

        s_lancaChildPool.setDstPool(chainSelector, poolAddress);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.zeroAddress
            )
        );
        s_lancaChildPool.setDstPool(chainSelector, ZERO_ADDRESS);

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

    function test_distributeLiquidityInvalidAddress_revert() public {
        address messenger = s_lancaChildPool.exposed_getMessengers()[0];
        vm.startPrank(messenger);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.zeroAddress
            )
        );
        s_lancaChildPool.distributeLiquidity(0, 0, bytes32(0));

        vm.stopPrank();
    }

    function test_distributeLiquidityDistributeLiquidityRequestAlreadyProceeded_revert() public {
        address messenger = s_lancaChildPool.exposed_getMessengers()[0];
        uint64 chainSelector = 1;
        uint256 amountToSend = 1 * USDC_DECIMALS;
        bytes32 distributeLiquidityRequestId = bytes32(0);
        address pool = makeAddr("pool");

        vm.prank(s_deployChildPoolHarnessScript.getDeployer());
        s_lancaChildPool.setDstPool(chainSelector, pool);

        deal(s_usdc, address(s_lancaChildPool), 100 * USDC_DECIMALS);

        vm.startPrank(messenger);

        s_lancaChildPool.distributeLiquidity(
            chainSelector,
            amountToSend,
            distributeLiquidityRequestId
        );

        vm.expectRevert(ILancaPool.DistributeLiquidityRequestAlreadyProceeded.selector);
        s_lancaChildPool.distributeLiquidity(
            chainSelector,
            amountToSend,
            distributeLiquidityRequestId
        );

        vm.stopPrank();
    }

    /* CCIP SEND TO POOL */

    function test_ccipSendToPoolNotMessenger_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notMessenger
            )
        );
        s_lancaChildPool.ccipSendToPool(0, 0, bytes32(0));
    }

    function test_ccipSendToPoolInvalidAddress_revert() public {
        vm.prank(s_lancaChildPool.exposed_getMessengers()[0]);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.zeroAddress
            )
        );
        s_lancaChildPool.ccipSendToPool(0, 0, bytes32(0));
    }

    function test_ccipSendToPoolWithdrawalAlreadyTriggered_revert() public {
        uint64 chainSelector = 1;
        address pool = makeAddr("pool");
        bytes32 withdrawalRequestId = bytes32(0);
        uint256 amountToSend = 1 * USDC_DECIMALS;

        s_lancaChildPool.exposed_setDstPoolByChainSelector(chainSelector, pool);
        s_lancaChildPool.exposed_setIsWithdrawalRequestTriggered(withdrawalRequestId, true);

        vm.prank(s_lancaChildPool.exposed_getMessengers()[0]);
        vm.expectRevert(ILancaPool.WithdrawalAlreadyTriggered.selector);
        s_lancaChildPool.ccipSendToPool(chainSelector, amountToSend, withdrawalRequestId);
    }

    /* LIQUIDATE POOL */

    function test_liquidatePoolNotMessenger_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notMessenger
            )
        );
        s_lancaChildPool.liquidatePool(bytes32(0));
    }

    function test_liquidatePoolDistributeLiquidityRequestAlreadyProceeded_revert() public {
        bytes32 distributeLiquidityRequestId = bytes32(0);
        s_lancaChildPool.exposed_setDistributeLiquidityRequestProcessed(
            distributeLiquidityRequestId,
            true
        );

        vm.prank(s_lancaChildPool.exposed_getMessengers()[0]);
        vm.expectRevert(ILancaPool.DistributeLiquidityRequestAlreadyProceeded.selector);
        s_lancaChildPool.liquidatePool(distributeLiquidityRequestId);
    }

    function test_liquidatePoolNoPoolsToDistribute_revert() public {
        bytes32 distributeLiquidityRequestId = bytes32(0);

        vm.prank(s_lancaChildPool.exposed_getMessengers()[0]);
        vm.expectRevert(ILancaChildPool.NoPoolsToDistribute.selector);
        s_lancaChildPool.liquidatePool(distributeLiquidityRequestId);
    }

    /* TAKE LOAN */
    function test_takeLoanUnauthorized_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notLancaBridge
            )
        );
        s_lancaChildPool.takeLoan(s_usdc, 0, address(0));
    }

    function test_takeLoanInvalidAddress_revert() public {
        vm.prank(s_lancaChildPool.exposed_getLancaBridge());
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.zeroAddress
            )
        );
        s_lancaChildPool.takeLoan(s_usdc, 0, address(0));
    }

    function test_takeLoanNotUsdcToken_revert() public {
        vm.prank(s_lancaChildPool.exposed_getLancaBridge());
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.notUsdcToken
            )
        );
        s_lancaChildPool.takeLoan(makeAddr("usdt"), 0, makeAddr("receiver"));
    }
}
