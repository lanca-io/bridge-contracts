// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {Vm} from "forge-std/src/Vm.sol";
import {console} from "forge-std/src/console.sol";
import {ILancaParentPool} from "contracts/pools/interfaces/ILancaParentPool.sol";
import {DeployLancaParentPoolHarnessScript} from "../scripts/DeployLancaParentPoolHarness.s.sol";
import {LancaParentPoolHarness} from "../harnesses/LancaParentPoolHarness.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LibErrors} from "contracts/common/libraries/LibErrors.sol";
import {ZERO_ADDRESS} from "contracts/common/Constants.sol";
import {CHAIN_SELECTOR_ARBITRUM} from "contracts/common/Constants.sol";
import {ILancaParentPool} from "contracts/pools/interfaces/ILancaParentPool.sol";
import {ILancaParentPoolCLFCLA} from "contracts/pools/interfaces/ILancaParentPoolCLFCLA.sol";
import {ILancaPool} from "contracts/pools/interfaces/ILancaPool.sol";

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
            uint8(ILancaParentPool.ClfRequestType.startDeposit_getChildPoolsLiquidity)
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

        uint256 depositFeesSumBefore = s_lancaParentPool.exposed_getDepositFeesSum();
        uint256 depositorBalanceBefore = IERC20(s_usdc).balanceOf(s_depositor);

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

        uint256 depositFeesSumAfter = s_lancaParentPool.exposed_getDepositFeesSum();
        uint256 depositFeeAmount = s_lancaParentPool.exposed_getDepositFeeAmount();
        uint256 depositorBalanceAfter = IERC20(s_usdc).balanceOf(s_depositor);

        ILancaParentPool.DepositRequest memory depositReq = s_lancaParentPool.getDepositRequestById(
            depositId
        );

        vm.assertEq(depositorBalanceAfter, depositorBalanceBefore - depositAmount);
        vm.assertEq(depositFeesSumAfter, depositFeesSumBefore + depositFeeAmount);
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

    function testFuzz_withdrawDepositFees(uint256 amount) public {
        vm.assume(amount > 0 && amount < 100000 * USDC_DECIMALS);

        s_lancaParentPool.exposed_setDepositFeesSum(amount);
        address deployer = s_deployLancaParentPoolHarnessScript.getDeployer();
        uint256 deployerBalanceBefore = IERC20(s_usdc).balanceOf(deployer);

        _dealUsdcTo(address(s_lancaParentPool), amount);

        vm.prank(deployer);
        s_lancaParentPool.withdrawDepositFees();

        uint256 deployerBalanceAfter = IERC20(s_usdc).balanceOf(deployer);
        uint256 lancaParentPoolBalanceAfter = IERC20(s_usdc).balanceOf(address(s_lancaParentPool));

        vm.assertEq(deployerBalanceAfter, deployerBalanceBefore + amount);
        vm.assertEq(lancaParentPoolBalanceAfter, 0);
    }

    function testFuzz_distributeLiquidity(
        uint64 chainSelector,
        uint256 amountToSend,
        bytes32 requestId
    ) public {
        vm.assume(amountToSend > 0 && amountToSend < 100000 * USDC_DECIMALS);

        s_lancaParentPool.exposed_setDstPoolByChainSelector(chainSelector, makeAddr("pool"));
        address messenger = s_lancaParentPool.exposed_getMessengers()[0];

        _dealUsdcTo(address(s_lancaParentPool), amountToSend);

        vm.startPrank(messenger);
        IERC20(s_usdc).approve(address(s_lancaParentPool), amountToSend);
        s_lancaParentPool.distributeLiquidity(chainSelector, amountToSend, requestId);

        vm.stopPrank();

        vm.assertEq(
            s_lancaParentPool.exposed_getDistributeLiquidityRequestProcessed(requestId),
            true
        );
    }

    /* HANDLE ORACLE FULFILLMENT */

    function test_handleOracleFulfillmentDepositGetChildPoolsLiqWithError() public {
        bytes32 clfReqId = keccak256("clfReqId");
        bytes memory response;
        bytes memory err = abi.encode("error");

        s_lancaParentPool.exposed_setClfReqTypeById(
            clfReqId,
            ILancaParentPool.ClfRequestType.startDeposit_getChildPoolsLiquidity
        );

        vm.startPrank(s_lancaParentPool.exposed_getClfRouter());
        vm.expectEmit(false, false, false, true, address(s_lancaParentPool));
        emit ILancaParentPoolCLFCLA.ClfRequestError(
            clfReqId,
            ILancaParentPool.ClfRequestType.startDeposit_getChildPoolsLiquidity,
            err
        );
        s_lancaParentPool.handleOracleFulfillment(clfReqId, response, err);
        vm.stopPrank();

        vm.assertEq(
            uint8(s_lancaParentPool.getClfReqTypeById(clfReqId)),
            uint8(ILancaParentPool.ClfRequestType.empty)
        );
    }

    function testFuzz_handleOracleFulfillmentWithdrawalGetChildPoolsLiqWithError(
        uint256 amountToWithdraw
    ) public {
        vm.assume(amountToWithdraw > 1e18 && amountToWithdraw < 100_000_000_000e18);

        bytes32 clfReqId = keccak256("clfReqId");
        bytes memory response;
        bytes memory err = abi.encode("error");
        bytes32 withdrawalId = keccak256("withdrawalId");
        address lpToken = s_lancaParentPool.exposed_getLpToken();

        deal(lpToken, address(s_lancaParentPool), amountToWithdraw);
        uint256 depositorBalanceBefore = IERC20(lpToken).balanceOf(s_depositor);

        s_lancaParentPool.exposed_setClfReqTypeById(
            clfReqId,
            ILancaParentPool.ClfRequestType.startWithdrawal_getChildPoolsLiquidity
        );
        s_lancaParentPool.exposed_setWithdrawalIdByClfRequestId(clfReqId, withdrawalId);
        s_lancaParentPool.exposed_setWithdrawalReqById(
            withdrawalId,
            ILancaParentPool.WithdrawRequest({
                lpAddress: s_depositor,
                lpAmountToBurn: amountToWithdraw,
                // @dev rest of the fields are not important for this test
                amountToWithdraw: 0,
                liquidityRequestedFromEachPool: 0,
                remainingLiquidityFromChildPools: 0,
                triggeredAtTimestamp: 0,
                totalCrossChainLiquiditySnapshot: 0
            })
        );

        vm.startPrank(s_lancaParentPool.exposed_getClfRouter());
        vm.expectEmit(false, false, false, true, address(s_lancaParentPool));
        emit ILancaParentPoolCLFCLA.ClfRequestError(
            clfReqId,
            ILancaParentPool.ClfRequestType.startWithdrawal_getChildPoolsLiquidity,
            err
        );
        s_lancaParentPool.handleOracleFulfillment(clfReqId, response, err);
        vm.stopPrank();

        vm.assertEq(
            uint8(s_lancaParentPool.getClfReqTypeById(clfReqId)),
            uint8(ILancaParentPool.ClfRequestType.empty)
        );
        vm.assertEq(
            IERC20(lpToken).balanceOf(s_depositor),
            depositorBalanceBefore + amountToWithdraw
        );
        vm.assertEq(IERC20(lpToken).balanceOf(address(s_lancaParentPool)), 0);
    }

    function test_handleOracleFulfillmentDepositGetChildPoolsLiqSuccess() public {
        bytes32 clfReqId = keccak256("clfReqId");
        uint256 amountUsdcToDeposit = 85_000 * USDC_DECIMALS;
        bytes memory response = abi.encode(amountUsdcToDeposit);
        bytes memory err;

        s_lancaParentPool.exposed_setClfReqTypeById(
            clfReqId,
            ILancaParentPool.ClfRequestType.startDeposit_getChildPoolsLiquidity
        );

        vm.assertEq(
            s_lancaParentPool.getDepositRequestById(clfReqId).childPoolsLiquiditySnapshot,
            0
        );

        vm.prank(s_lancaParentPool.exposed_getClfRouter());
        s_lancaParentPool.handleOracleFulfillment(clfReqId, response, err);

        vm.assertEq(
            s_lancaParentPool.getDepositRequestById(clfReqId).childPoolsLiquiditySnapshot,
            amountUsdcToDeposit
        );
        vm.assertEq(
            uint8(s_lancaParentPool.getClfReqTypeById(clfReqId)),
            uint8(ILancaParentPool.ClfRequestType.empty)
        );
    }

    function test_handleOracleFulfillmentStartWithdrawalGetChildPoolsLiqSuccess() public {
        bytes32 clfReqId = keccak256("clfReqId");
        uint256 amountUsdcToWithdraw = 85_000 * USDC_DECIMALS;
        bytes memory response = abi.encode(amountUsdcToWithdraw);
        bytes memory err;

        s_lancaParentPool.exposed_setClfReqTypeById(
            clfReqId,
            ILancaParentPool.ClfRequestType.startWithdrawal_getChildPoolsLiquidity
        );

        vm.assertEq(
            s_lancaParentPool.getWithdrawalRequestById(clfReqId).totalCrossChainLiquiditySnapshot,
            0
        );

        vm.prank(s_lancaParentPool.exposed_getClfRouter());
        s_lancaParentPool.handleOracleFulfillment(clfReqId, response, err);

        vm.assertEq(
            s_lancaParentPool.getWithdrawalRequestById(clfReqId).totalCrossChainLiquiditySnapshot,
            amountUsdcToWithdraw
        );
        vm.assertEq(
            uint8(s_lancaParentPool.getClfReqTypeById(clfReqId)),
            uint8(ILancaParentPool.ClfRequestType.empty)
        );
    }

    function test_performUpkeep() public {
        bytes memory data = abi.encode("withdrawalId");
        bytes32 withdrawalId = bytes32(data);
        uint256 amountToWithdraw = 10 * USDC_DECIMALS;
        uint256 liquidityRequestedFromEachPool = 1 * USDC_DECIMALS;

        ILancaParentPool.WithdrawRequest memory withdrawalReq = ILancaParentPool.WithdrawRequest({
            lpAddress: makeAddr("lpAddress"),
            lpAmountToBurn: 0,
            totalCrossChainLiquiditySnapshot: 0,
            amountToWithdraw: amountToWithdraw,
            liquidityRequestedFromEachPool: liquidityRequestedFromEachPool,
            remainingLiquidityFromChildPools: 0,
            triggeredAtTimestamp: 0
        });

        s_lancaParentPool.exposed_setWithdrawalReqById(withdrawalId, withdrawalReq);

        vm.recordLogs();

        address automationForwarder = s_lancaParentPool.exposed_getAutomationForwarder();
        vm.prank(automationForwarder);

        s_lancaParentPool.performUpkeep(data);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 reqId = abi.decode(entries[3].data, (bytes32));
        ILancaParentPool.ClfRequestType requestType = s_lancaParentPool
            .exposed_getClfRequestTypeById(reqId);

        vm.assertEq(entries.length, 4);
        vm.assertEq(entries[3].topics[0], ILancaParentPoolCLFCLA.WithdrawUpkeepPerformed.selector);

        vm.assertEq(
            uint8(requestType),
            uint8(ILancaParentPool.ClfRequestType.withdrawal_requestLiquidityCollection)
        );

        vm.assertEq(s_lancaParentPool.exposed_getWithdrawalIdByCLFRequestId(reqId), withdrawalId);
        vm.assertEq(
            s_lancaParentPool.exposed_getWithdrawalsOnTheWayAmount(),
            amountToWithdraw - liquidityRequestedFromEachPool
        );
    }

    function test_checkUpkeepReturnsFalse() public {
        bytes memory checkData = abi.encode("checkUpkeep");
        vm.prank(s_lancaParentPool.exposed_getAutomationForwarder(), ZERO_ADDRESS);
        (bool isNeeded, ) = s_lancaParentPool.checkUpkeep(checkData);
        vm.assertEq(isNeeded, false);
    }

    function test_checkUpkeepReturnsTrue() public {
        bytes memory checkData = abi.encode("checkUpkeep");
        bytes32[] memory withdrawalRequestIds = new bytes32[](1);
        withdrawalRequestIds[0] = keccak256("withdrawalRequestIds");
        s_lancaParentPool.exposed_setWithdrawalRequestIds(withdrawalRequestIds);

        s_lancaParentPool.exposed_setWithdrawalReqById(
            withdrawalRequestIds[0],
            ILancaParentPool.WithdrawRequest({
                lpAddress: makeAddr("lpAddress"),
                lpAmountToBurn: 0,
                totalCrossChainLiquiditySnapshot: 0,
                amountToWithdraw: 1 * USDC_DECIMALS,
                liquidityRequestedFromEachPool: 0,
                remainingLiquidityFromChildPools: 0,
                triggeredAtTimestamp: 0
            })
        );

        vm.prank(s_lancaParentPool.exposed_getAutomationForwarder(), ZERO_ADDRESS);
        (bool isNeeded, bytes memory res) = s_lancaParentPool.checkUpkeep(checkData);
        vm.assertEq(isNeeded, true);
        vm.assertEq(abi.decode(res, (bytes32)), withdrawalRequestIds[0]);
    }

    /* ADMIN FUNCTIONS */

    function testFuzz_setDstPool(
        uint64 chainSelector,
        address pool,
        bool isRebalancingNeeded
    ) public {
        vm.assume(pool != ZERO_ADDRESS);
        vm.prank(s_deployLancaParentPoolHarnessScript.getDeployer());
        s_lancaParentPool.setDstPool(chainSelector, pool, isRebalancingNeeded);

        vm.assertEq(s_lancaParentPool.exposed_getDstPoolByChainSelector(chainSelector), pool);
        vm.assertEq(s_lancaParentPool.exposed_getPoolChainSelectors()[0], chainSelector);
    }

    function testFuzz_removePools(
        uint64 chainSelector,
        address pool,
        bool isRebalancingNeeded
    ) public {
        vm.assume(pool != ZERO_ADDRESS);

        vm.startPrank(s_deployLancaParentPoolHarnessScript.getDeployer());
        s_lancaParentPool.setDstPool(chainSelector, pool, isRebalancingNeeded);
        uint256 poolChainSelectorsLenBefore = s_lancaParentPool
            .exposed_getPoolChainSelectors()
            .length;
        s_lancaParentPool.removePools(chainSelector);
        vm.stopPrank();

        vm.assertEq(
            s_lancaParentPool.exposed_getDstPoolByChainSelector(chainSelector),
            ZERO_ADDRESS
        );
        vm.assertEq(
            s_lancaParentPool.exposed_getPoolChainSelectors().length,
            poolChainSelectorsLenBefore - 1
        );
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

    /* START WITHDRAWAL */

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

    function test_setDstPoolInvalidAddress_revert() public {
        address poolAddress = makeAddr("pool");
        uint64 chainSelector = 2;
        vm.startPrank(s_deployLancaParentPoolHarnessScript.getDeployer());

        s_lancaParentPool.setDstPool(chainSelector, poolAddress, false);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.zeroAddress
            )
        );
        s_lancaParentPool.setDstPool(chainSelector, ZERO_ADDRESS, false);

        vm.stopPrank();
    }

    function test_setDstPoolTheSamePool_revert() public {
        address poolAddress = makeAddr("pool");
        uint64 chainSelector = 1;
        vm.startPrank(s_deployLancaParentPoolHarnessScript.getDeployer());

        s_lancaParentPool.setDstPool(chainSelector, poolAddress, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.sameAddress
            )
        );
        s_lancaParentPool.setDstPool(chainSelector, poolAddress, false);

        vm.stopPrank();
    }

    function test_setDstPoolNotOwner_revert() public {
        address poolAddress = makeAddr("pool");
        uint64 chainSelector = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notOwner
            )
        );
        s_lancaParentPool.setDstPool(chainSelector, poolAddress, false);
    }

    /* REMOVE POOLS */
    function test_removePoolsNotOwner_revert() public {
        uint64 chainSelector = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notOwner
            )
        );
        s_lancaParentPool.removePools(chainSelector);
    }

    /* WITHDRAW DEPOSIT FEES */

    function test_withdrawDepositFeesNotOwner_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notOwner
            )
        );
        s_lancaParentPool.withdrawDepositFees();
    }

    /* DISTRIBUTE LIQUIDITY */

    function test_distributeLiquidityNotMessenger_revert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notMessenger
            )
        );
        s_lancaParentPool.distributeLiquidity(0, 0, bytes32(0));
    }

    function test_distributeLiquidityInvalidAddress_revert() public {
        address messenger = s_lancaParentPool.exposed_getMessengers()[0];
        vm.prank(messenger);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.zeroAddress
            )
        );
        s_lancaParentPool.distributeLiquidity(0, 0, bytes32(0));
    }

    function test_distributeLiquidityDistributeLiquidityRequestAlreadyProceeded_revert() public {
        uint64 chainSelector = 0;
        address pool = makeAddr("pool");
        bytes32 distributeLiquidityRequestId = bytes32(0);
        uint256 amount = 0;

        s_lancaParentPool.exposed_setDstPoolByChainSelector(chainSelector, pool);
        address messenger = s_lancaParentPool.exposed_getMessengers()[0];
        s_lancaParentPool.exposed_setDistributeLiquidityRequestProcessed(
            distributeLiquidityRequestId,
            true
        );
        vm.prank(messenger);

        vm.expectRevert(ILancaPool.DistributeLiquidityRequestAlreadyProceeded.selector);
        s_lancaParentPool.distributeLiquidity(chainSelector, amount, distributeLiquidityRequestId);
    }

    /* PERFORM UPKEEP */

    function test_performUpkeepNotAutomationForwarder_revert() public {
        bytes memory data = abi.encode("performUpkeep()");
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notAutomationForwarder
            )
        );
        s_lancaParentPool.performUpkeep(data);
    }

    function test_performUpkeepWithdrawalRequestDoesntExist_revert() public {
        bytes memory data = abi.encode(0);
        address automationForwarder = s_lancaParentPool.exposed_getAutomationForwarder();
        vm.prank(automationForwarder);
        vm.expectRevert(
            abi.encodeWithSelector(ILancaParentPool.WithdrawRequestDoesntExist.selector, bytes32(0))
        );
        try s_lancaParentPool.performUpkeep(data) {
            revert("Expected revert, but got success");
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert("Expected revert, but got nothing");
            }
        }
    }

    function test_performUpkeepWithdrawalRequestNotReady_revert() public {
        bytes memory data = abi.encode("withdrawalId");
        bytes32 withdrawalId = bytes32(data);

        ILancaParentPool.WithdrawRequest memory withdrawalReq = ILancaParentPool.WithdrawRequest({
            lpAddress: makeAddr("lpAddress"),
            lpAmountToBurn: 0,
            totalCrossChainLiquiditySnapshot: 0,
            amountToWithdraw: 10 * USDC_DECIMALS,
            liquidityRequestedFromEachPool: 1 * USDC_DECIMALS,
            remainingLiquidityFromChildPools: 0,
            triggeredAtTimestamp: block.timestamp + 7 days
        });

        s_lancaParentPool.exposed_setWithdrawalReqById(withdrawalId, withdrawalReq);

        address automationForwarder = s_lancaParentPool.exposed_getAutomationForwarder();
        vm.prank(automationForwarder);

        vm.expectRevert(
            abi.encodeWithSelector(
                ILancaParentPoolCLFCLA.WithdrawalRequestNotReady.selector,
                withdrawalId
            )
        );
        try s_lancaParentPool.performUpkeep(data) {
            revert("Expected revert, but got success");
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert("Expected revert, but got nothing");
            }
        }
    }

    function test_performUpkeepWithdrawalAlreadyTriggered_revert() public {
        bytes memory data = abi.encode("withdrawalId");
        bytes32 withdrawalId = bytes32(data);

        ILancaParentPool.WithdrawRequest memory withdrawalReq = ILancaParentPool.WithdrawRequest({
            lpAddress: makeAddr("lpAddress"),
            lpAmountToBurn: 0,
            totalCrossChainLiquiditySnapshot: 0,
            amountToWithdraw: 10 * USDC_DECIMALS,
            liquidityRequestedFromEachPool: 1 * USDC_DECIMALS,
            remainingLiquidityFromChildPools: 0,
            triggeredAtTimestamp: block.timestamp
        });

        s_lancaParentPool.exposed_setWithdrawalReqById(withdrawalId, withdrawalReq);
        s_lancaParentPool.exposed_setWithdrawTriggered(withdrawalId, true);

        address automationForwarder = s_lancaParentPool.exposed_getAutomationForwarder();
        vm.prank(automationForwarder);

        vm.expectRevert(
            abi.encodeWithSelector(ILancaPool.WithdrawalAlreadyTriggered.selector, withdrawalId)
        );
        try s_lancaParentPool.performUpkeep(data) {
            revert("Expected revert, but got success");
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert("Expected revert, but got nothing");
            }
        }
    }

    function test_handleOracleFulfillmentOnlyRouterCanFulfill_revert() public {
        bytes32 requestId = keccak256("requestId");
        bytes memory delegateCallResponse = abi.encode("delegateCallResponse");
        bytes memory err = abi.encode("err");
        address sender = makeAddr("sender");

        vm.prank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(ILancaParentPool.OnlyRouterCanFulfill.selector, sender)
        );
        s_lancaParentPool.handleOracleFulfillment(requestId, delegateCallResponse, err);
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
