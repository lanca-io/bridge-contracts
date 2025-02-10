// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {Vm} from "forge-std/src/Vm.sol";
import {console} from "forge-std/src/console.sol";
import {ILancaParentPool} from "contracts/pools/interfaces/ILancaParentPool.sol";
import {DeployLancaParentPoolHarnessScript} from "../scripts/DeployLancaParentPoolHarness.s.sol";
import {LancaParentPoolHarness} from "../harnesses/LancaParentPoolHarness.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LibErrors} from "contracts/common/libraries/LibErrors.sol";
import {ZERO_ADDRESS} from "contracts/common/Constants.sol";

contract LancaParentPoolTest is Test {
    uint256 internal constant USDC_DECIMALS = 1e6;
    uint256 internal constant DEPOSIT_AMOUNT = 100 * USDC_DECIMALS;
    uint256 internal constant LOW_DEPOSIT_AMOUNT = 1 * USDC_DECIMALS;

    DeployLancaParentPoolHarnessScript internal s_deployLancaParentPoolHarnessScript;
    LancaParentPoolHarness internal s_lancaParentPool;
    address internal s_usdc = vm.envAddress("USDC_BASE");
    address internal s_depositor = makeAddr("depositor");

    modifier dealUsdcTo(address to, uint256 amount) {
        _dealUsdcTo(to, amount);
        _;
    }

    function setUp() public {
        uint256 forkId = vm.createSelectFork(vm.envString("RPC_URL_BASE"), 26000933);
        s_deployLancaParentPoolHarnessScript = new DeployLancaParentPoolHarnessScript();
        s_lancaParentPool = LancaParentPoolHarness(
            payable(s_deployLancaParentPoolHarnessScript.run(forkId))
        );
        vm.prank(s_deployLancaParentPoolHarnessScript.getDeployer());
        s_lancaParentPool.setPoolCap(60_000 * USDC_DECIMALS);
    }

    /* FUZZING */

    function testFuzz_startDeposit(uint256 depositAmount) public {
        vm.assume(
            depositAmount > s_lancaParentPool.getMinDepositAmount() &&
                depositAmount < s_lancaParentPool.getLiquidityCap()
        );

        uint256 depositDeadline = block.timestamp + s_lancaParentPool.getDepositDeadlineSeconds();

        vm.startPrank(s_depositor);
        vm.expectEmit(false, false, false, true, address(s_lancaParentPool));
        emit ILancaParentPool.DepositInitiated(
            bytes32(0),
            s_depositor,
            depositAmount,
            depositDeadline
        );
        bytes32 depositId = s_lancaParentPool.startDeposit(depositAmount);
        vm.stopPrank();

        ILancaParentPool.DepositRequest memory depositReq = s_lancaParentPool.getDepositRequestById(
            depositId
        );

        // @dev check clf req type by id
        vm.assertEq(
            uint8(s_lancaParentPool.getClfReqTypeById(depositId)),
            uint8(ILancaParentPool.CLFRequestType.startDeposit_getChildPoolsLiquidity)
        );

        // @dev check full deposit request structure
        vm.assertEq(depositReq.lpAddress, s_depositor);
        vm.assertEq(depositReq.usdcAmountToDeposit, depositAmount);
        vm.assertEq(depositReq.deadline, depositDeadline);
        vm.assertEq(depositReq.childPoolsLiquiditySnapshot, 0);
    }

    function testFuzz_completeDeposit(uint256 depositAmount) public {
        vm.assume(
            depositAmount > s_lancaParentPool.getMinDepositAmount() &&
                depositAmount < s_lancaParentPool.getLiquidityCap()
        );
        _dealUsdcTo(s_depositor, depositAmount);

        console.logUint(IERC20(s_usdc).balanceOf(s_depositor));

        vm.startPrank(s_depositor);
        bytes32 depositId = s_lancaParentPool.startDeposit(depositAmount);
        uint256 childPoolLiquidity = 85_000 * USDC_DECIMALS;
        s_lancaParentPool.exposed_setChildPoolsLiqSnapshotByDepositId(
            depositId,
            childPoolLiquidity
        );
        IERC20(s_usdc).approve(address(s_lancaParentPool), depositAmount);
        s_lancaParentPool.completeDeposit(depositId);
        vm.stopPrank();

        ILancaParentPool.DepositRequest memory depositReq = s_lancaParentPool.getDepositRequestById(
            depositId
        );

        vm.assertEq(depositReq.childPoolsLiquiditySnapshot, 0);
        vm.assertEq(depositReq.usdcAmountToDeposit, 0);
        vm.assertEq(depositReq.lpAddress, ZERO_ADDRESS);
        vm.assertEq(depositReq.deadline, 0);
        vm.assertGe(IERC20(s_lancaParentPool.exposed_getLpToken()).totalSupply(), 0);
    }

    function testFuzz_startWithdrawal(uint256 lpAmountToWithdraw) public {
        vm.assume(lpAmountToWithdraw > 1e18 && lpAmountToWithdraw < 1_000_000_000e18);

        deal(s_lancaParentPool.exposed_getLpToken(), s_depositor, lpAmountToWithdraw);

        uint256 depositorLpTokenBalanceBefore = IERC20(s_lancaParentPool.exposed_getLpToken())
            .balanceOf(s_depositor);
        uint256 poolLpTokenBalanceBefore = IERC20(s_lancaParentPool.exposed_getLpToken()).balanceOf(
            address(s_lancaParentPool)
        );

        vm.startPrank(s_depositor);
        IERC20(s_lancaParentPool.exposed_getLpToken()).approve(
            address(s_lancaParentPool),
            lpAmountToWithdraw
        );
        s_lancaParentPool.startWithdrawal(lpAmountToWithdraw);
        vm.stopPrank();

        ILancaParentPool.WithdrawRequest memory withdrawReq = s_lancaParentPool
            .getWithdrawalRequestById(s_lancaParentPool.getWithdrawalIdByLPAddress(s_depositor));

        uint256 depositorLpTokenBalanceAfter = IERC20(s_lancaParentPool.exposed_getLpToken())
            .balanceOf(s_depositor);
        uint256 poolLpTokenBalanceAfter = IERC20(s_lancaParentPool.exposed_getLpToken()).balanceOf(
            address(s_lancaParentPool)
        );

        // @dev check full withdraw request structure
        vm.assertEq(withdrawReq.lpAddress, s_depositor);
        vm.assertEq(withdrawReq.lpAmountToBurn, lpAmountToWithdraw);
        vm.assertEq(withdrawReq.amountToWithdraw, 0);
        vm.assertEq(withdrawReq.liquidityRequestedFromEachPool, 0);
        vm.assertEq(withdrawReq.remainingLiquidityFromChildPools, 0);
        vm.assertEq(withdrawReq.triggeredAtTimestamp, 0);

        // @dev check lp token balances
        vm.assertEq(
            depositorLpTokenBalanceAfter,
            depositorLpTokenBalanceBefore - lpAmountToWithdraw
        );
        vm.assertEq(poolLpTokenBalanceAfter, poolLpTokenBalanceBefore + lpAmountToWithdraw);
    }

    //    function test_handleOracleFulfillment() public {
    //        bytes32 clfReqId = keccak256("clfReqId");
    //        bytes memory data;
    //        bytes memory err;
    //    }
    //}

    function testFuzz_setPools(
        uint64 chainSelector,
        address pool,
        bool isRebalancingNeeded
    ) public {
        vm.assume(pool != ZERO_ADDRESS);
        vm.prank(s_deployLancaParentPoolHarnessScript.getDeployer());
        s_lancaParentPool.setPools(chainSelector, pool, isRebalancingNeeded);

        vm.assertEq(s_lancaParentPool.exposed_getDstPoolByChainSelector(chainSelector), pool);
        vm.assertEq(s_lancaParentPool.exposed_getPoolChainSelectors()[0], chainSelector);
    }

    /* REVERTS */

    /* START DEPOSIT */

    function test_startDepositDepositAmountBelowMinimum_revert() public {
        vm.prank(s_depositor);
        vm.expectRevert(ILancaParentPool.DepositAmountBelowMinimum.selector);
        s_lancaParentPool.startDeposit(LOW_DEPOSIT_AMOUNT);
    }

    function test_startDepositMaxDepositCapReached_revert() public {
        vm.prank(s_depositor);
        uint256 liqCap = s_lancaParentPool.getLiquidityCap();
        vm.expectRevert(ILancaParentPool.MaxDepositCapReached.selector);
        s_lancaParentPool.startDeposit(liqCap + 1);
    }

    function test_startWithdrawalWithdrawAmountBelowMinimum_revert() public {
        vm.prank(s_depositor);
        vm.expectRevert(ILancaParentPool.WithdrawAmountBelowMinimum.selector);
        s_lancaParentPool.startWithdrawal(0);
    }

    function test_startWithdrawalRequestAlreadyExists_revert() public {
        uint256 lpAmountToWithdraw = 1000e18;
        deal(s_lancaParentPool.exposed_getLpToken(), s_depositor, lpAmountToWithdraw);
        vm.startPrank(s_depositor);
        IERC20(s_lancaParentPool.exposed_getLpToken()).approve(
            address(s_lancaParentPool),
            lpAmountToWithdraw
        );
        s_lancaParentPool.startWithdrawal(lpAmountToWithdraw);
        vm.expectRevert(ILancaParentPool.WithdrawalRequestAlreadyExists.selector);
        s_lancaParentPool.startWithdrawal(lpAmountToWithdraw);
        vm.stopPrank();
    }

    /* COMPLETE DEPOSIT */

    function test_completeDepositNotAllowedToCompleteDeposit_revert() public {
        uint256 depositAmount = s_lancaParentPool.getMinDepositAmount() + 1;
        bytes32 depositId = _startDeposit(depositAmount);
        vm.expectRevert(ILancaParentPool.NotAllowedToCompleteDeposit.selector);
        s_lancaParentPool.completeDeposit(depositId);
    }

    function test_completeDepositDepositDeadlinePassed_revert() public {
        uint256 depositAmount = s_lancaParentPool.getMinDepositAmount() + 1;
        bytes32 depositId = _startDeposit(depositAmount);

        vm.warp(block.timestamp + s_lancaParentPool.getDepositDeadlineSeconds() + 1);

        vm.prank(s_depositor);
        vm.expectRevert(ILancaParentPool.DepositDeadlinePassed.selector);
        s_lancaParentPool.completeDeposit(depositId);
    }

    function test_completeDepositDepositRequestNotReady_revert() public {
        uint256 depositAmount = s_lancaParentPool.getMinDepositAmount() + 1;
        bytes32 depositId = _startDeposit(depositAmount);

        vm.prank(s_depositor);
        vm.expectRevert(ILancaParentPool.DepositRequestNotReady.selector);
        s_lancaParentPool.completeDeposit(depositId);
    }

    /* SET POOLS */

    function test_setPoolsInvalidAddress_revert() public {
        address poolAddress = makeAddr("pool");
        uint64 chainSelector = 2;
        vm.startPrank(s_deployLancaParentPoolHarnessScript.getDeployer());

        s_lancaParentPool.setPools(chainSelector, poolAddress, false);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.zeroAddress
            )
        );
        s_lancaParentPool.setPools(chainSelector, ZERO_ADDRESS, false);

        vm.stopPrank();
    }

    function test_setPoolsTheSamePool_revert() public {
        address poolAddress = makeAddr("pool");
        uint64 chainSelector = 1;
        vm.startPrank(s_deployLancaParentPoolHarnessScript.getDeployer());

        s_lancaParentPool.setPools(chainSelector, poolAddress, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.sameAddress
            )
        );
        s_lancaParentPool.setPools(chainSelector, poolAddress, false);

        vm.stopPrank();
    }

    function test_setPoolsNotOwner_revert() public {
        address poolAddress = makeAddr("pool");
        uint64 chainSelector = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notOwner
            )
        );
        s_lancaParentPool.setPools(chainSelector, poolAddress, false);
    }

    /* HELPERS */

    function _dealUsdcTo(address to, uint256 amount) internal {
        deal(s_usdc, to, amount);
    }

    function _startDeposit(uint256 depositAmount) internal returns (bytes32) {
        _dealUsdcTo(s_depositor, depositAmount);
        vm.prank(s_depositor);
        return s_lancaParentPool.startDeposit(depositAmount);
    }
}
