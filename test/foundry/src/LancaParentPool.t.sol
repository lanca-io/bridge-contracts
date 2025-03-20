// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {Vm} from "forge-std/src/Vm.sol";
import {console} from "forge-std/src/console.sol";
import {ILancaParentPool} from "contracts/pools/interfaces/ILancaParentPool.sol";
import {ILancaPool} from "contracts/pools/interfaces/ILancaPool.sol";
import {LPToken} from "contracts/pools/LPToken.sol";
import {DeployLancaParentPoolHarnessScript} from "../scripts/DeployLancaParentPoolHarness.s.sol";
import {LancaParentPoolHarness} from "../harnesses/LancaParentPoolHarness.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LibErrors} from "contracts/common/libraries/LibErrors.sol";
import {ZERO_ADDRESS} from "contracts/common/Constants.sol";
import {ILancaParentPool} from "contracts/pools/interfaces/ILancaParentPool.sol";
import {ILancaParentPoolCLFCLA} from "contracts/pools/interfaces/ILancaParentPoolCLFCLA.sol";
import {ICcip} from "contracts/common/interfaces/ICcip.sol";
import {Client as LibCcipClient} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {ILancaBridge} from "contracts/bridge/interfaces/ILancaBridge.sol";

contract LancaParentPoolTest is Test {
    uint256 internal constant USDC_DECIMALS = 1e6;
    uint256 internal constant LP_TOKEN_DECIMALS = 1 ether;
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
        s_lancaParentPool.exposed_setWithdrawalIdByClfId(clfReqId, withdrawalId);
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
        vm.startPrank(messenger);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.InvalidAddress.selector,
                LibErrors.InvalidAddressType.zeroAddress
            )
        );
        s_lancaParentPool.distributeLiquidity(0, 0, bytes32(0));

        vm.stopPrank();
    }

    function test_distributeLiquidityDistributeLiquidityRequestAlreadyProceeded_revert() public {
        address messenger = s_lancaParentPool.exposed_getMessengers()[0];
        uint64 chainSelector = 1;
        uint256 amountToSend = 1 * USDC_DECIMALS;
        bytes32 distributeLiquidityRequestId = bytes32(0);
        address pool = makeAddr("pool");

        vm.prank(s_deployLancaParentPoolHarnessScript.getDeployer());
        s_lancaParentPool.setDstPool(chainSelector, pool, false);

        deal(s_usdc, address(s_lancaParentPool), 100 * USDC_DECIMALS);

        vm.startPrank(messenger);

        s_lancaParentPool.distributeLiquidity(
            chainSelector,
            amountToSend,
            distributeLiquidityRequestId
        );

        vm.expectRevert(ILancaPool.DistributeLiquidityRequestAlreadyProceeded.selector);
        s_lancaParentPool.distributeLiquidity(
            chainSelector,
            amountToSend,
            distributeLiquidityRequestId
        );

        vm.stopPrank();
        uint256 afterBalance = IERC20(s_usdc).balanceOf(address(s_lancaParentPool));
        vm.assertEq(afterBalance, 99 * USDC_DECIMALS);
    }

    /* REMOVE POOLS */

    function test_removePoolsNotOwner_revert() public {
        uint64 chainSelector = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notOwner
            )
        );
        s_lancaParentPool.removePools(chainSelector);
    }

    function test_removePools() public {
        uint64 chainSelector = 1;
        address pool = makeAddr("pool");

        vm.startPrank(s_deployLancaParentPoolHarnessScript.getDeployer());
        s_lancaParentPool.setDstPool(chainSelector, pool, false);

        s_lancaParentPool.removePools(chainSelector);

        vm.assertEq(s_lancaParentPool.exposed_getPoolChainSelectors().length, 0);
        vm.assertEq(
            s_lancaParentPool.exposed_getDstPoolByChainSelector(chainSelector),
            ZERO_ADDRESS
        );
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

    function test_withdrawDepositFees() public {
        uint256 feeAmount = 2 * USDC_DECIMALS;
        _dealUsdcTo(address(s_lancaParentPool), feeAmount);
        s_lancaParentPool.exposed_setDepositFeeAmount(feeAmount);

        uint256 beforeBalance = IERC20(s_usdc).balanceOf(address(s_lancaParentPool));
        vm.prank(s_deployLancaParentPoolHarnessScript.getDeployer());
        s_lancaParentPool.withdrawDepositFees();
        uint256 afterBalance = IERC20(s_usdc).balanceOf(address(s_lancaParentPool));

        vm.assertEq(beforeBalance,feeAmount);
        vm.assertEq(afterBalance,0);
    }

    /* CCIP RECEIVE FROM ROUTER */

    function test_ccipReceiveSettlementWithoutExecutionLayerFails() public {
        bytes32 withdrawalId = 0x0000000000000000000000000000000000000000000000000000000000000001;
        ICcip.CcipSettleMessage memory ccipTxs = ICcip.CcipSettleMessage({
        ccipTxType: ICcip.CcipTxType.withdrawal,
        data: abi.encode(withdrawalId)
        });

        LibCcipClient.EVMTokenAmount[] memory destTokenAmounts = new LibCcipClient.EVMTokenAmount[](
            2
        );

        destTokenAmounts[0].token = s_usdc;

        deal(s_usdc, address(s_lancaParentPool), 100 * USDC_DECIMALS);

        uint256 beforeLancaPoolBalance = IERC20(s_usdc).balanceOf(
            address(s_lancaParentPool)
        );

        address s_lancaBridgeArb = makeAddr("arb lanca bridge");
        uint64 chainSelector = 1;

        LibCcipClient.Any2EVMMessage memory ccipMessage = LibCcipClient.Any2EVMMessage({
            messageId: keccak256("ccip message id"),
            sourceChainSelector: chainSelector,
            sender: abi.encode(s_lancaBridgeArb),
            data: abi.encode(ccipTxs),
            destTokenAmounts: destTokenAmounts
        });

        vm.prank(s_lancaParentPool.getRouter());
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notAllowedSender
            )
        );
        s_lancaParentPool.ccipReceive(ccipMessage);

        s_lancaParentPool.exposed_setDstPoolByChainSelector(chainSelector, s_lancaBridgeArb);

        uint256 lpAmountToBurn = 10;
        uint256 amountToWithdraw = 3;
        address lpToken = address(s_lancaParentPool.exposed_getLpToken());
        deal(lpToken, address(s_lancaParentPool), lpAmountToBurn);

        ILancaParentPool.WithdrawRequest memory withdrawalRequest = ILancaParentPool.WithdrawRequest({
            lpAddress: lpToken,
            lpAmountToBurn: lpAmountToBurn,
            totalCrossChainLiquiditySnapshot: 0,
            amountToWithdraw: amountToWithdraw,
            liquidityRequestedFromEachPool: 1,
            remainingLiquidityFromChildPools: 1,
            triggeredAtTimestamp: 1
        });
        s_lancaParentPool.exposed_setWithdrawRequests(withdrawalId, withdrawalRequest);

        vm.prank(s_lancaParentPool.getRouter());
        s_lancaParentPool.ccipReceive(ccipMessage);

        uint256 afterLancaPoolBalance = IERC20(s_usdc).balanceOf(
            address(s_lancaParentPool)
        );

        assertEq(afterLancaPoolBalance, beforeLancaPoolBalance - amountToWithdraw);
    }

    /* CALCULATORS */

    function test_calculateWithdrawableAmountViaDelegateCall() public {
        uint256 childPoolsBalance = 10 * USDC_DECIMALS;
        uint256 clpAmount = 100;

        uint256 mintedLPAmount = 10 * LP_TOKEN_DECIMALS;
        _mintLpToken(address(s_lancaParentPool), mintedLPAmount);

        uint256 withdrawableAmount = s_lancaParentPool.calculateWithdrawableAmountViaDelegateCall(
            childPoolsBalance,clpAmount
        );
        assertEq(withdrawableAmount, 0);
    }

    function test_calculateLPTokensToMint() public {
        uint256 childPoolsBalance = 10 * USDC_DECIMALS;
        uint256 amountToDeposit = 5 * USDC_DECIMALS;
        uint256 beforeResult = s_lancaParentPool.calculateLPTokensToMint(childPoolsBalance, amountToDeposit);
        assertEq(beforeResult, 5 * LP_TOKEN_DECIMALS);

        uint256 mintedLPAmount = 9999 * LP_TOKEN_DECIMALS;
        _mintLpToken(address(s_lancaParentPool), mintedLPAmount);
        _dealUsdcTo(address(s_lancaParentPool), 999 * USDC_DECIMALS);

        uint256 afterResult = s_lancaParentPool.calculateLPTokensToMint(childPoolsBalance, amountToDeposit);
        assertGt(afterResult - beforeResult, 0);
    }

    /* UP KEEP */

    function test_performUpkeepNotAutomationForwarder_revert() public {
        bytes memory performData = new bytes(22);

        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notAutomationForwarder
            )
        );
        s_lancaParentPool.performUpkeep(performData);
    }

    function test_performUpkeepWithdrawalRequestDoesntExist_revert() public {
        bytes32 withdrawalId = bytes32(0);
        bytes memory performData = abi.encode(withdrawalId);

        vm.prank(s_lancaParentPool.exposed_getAutomationForwarder());
        vm.expectRevert(
            abi.encodeWithSelector(
                ILancaParentPoolCLFCLA.WithdrawalRequestDoesntExist.selector,
                    withdrawalId
            )
        );
        s_lancaParentPool.performUpkeep(performData);
    }

//    function test_performUpkeep() public {
//        vm.skip();
//        bytes32 withdrawalId = 0x0000000000000000000000000000000000000000000000000000000000000001;
//        bytes memory performData = abi.encode(withdrawalId);
//
//        vm.prank(s_lancaParentPool.exposed_getAutomationForwarder());
//        s_lancaParentPool.performUpkeep(performData);
//    }

    /* VIEW FUNCTIONS */

    function test_isFull() public {
        bool result = s_lancaParentPool.isFull();
        assertEq(result, false);

        s_lancaParentPool.exposed_setLiquidityCap(10);
        _dealUsdcTo(address(s_lancaParentPool), 10000 * USDC_DECIMALS);

        result = s_lancaParentPool.isFull();
        assertEq(result, true);
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

    function _mintLpToken(address to, uint256 mintedLPAmount) internal {
        LPToken lpToken = s_lancaParentPool.exposed_getILpToken();
        vm.prank(s_deployLancaParentPoolHarnessScript.getProxy());
        lpToken.mint(to, mintedLPAmount);
    }
}
