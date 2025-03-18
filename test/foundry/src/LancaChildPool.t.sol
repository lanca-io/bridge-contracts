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
import {Client as LibCcipClient} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {ICcip} from "contracts/common/interfaces/ICcip.sol";

import "../../../contracts/bridge/interfaces/ILancaBridge.sol";

contract LancaChildPoolTest is Test {
    uint256 internal constant USDC_DECIMALS = 1e6;
    bytes32 internal constant ANY_BYTES32 = 0x0000000000000000000000000000000000000000000000000000000000000001;

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
        uint256 beforeBalance = s_lancaChildPool.getUsdcLoansInUse();
        vm.assertEq(beforeBalance, amount);

        vm.startPrank(s_lancaChildPool.exposed_getLancaBridge());
        IERC20(s_usdc).approve(address(s_lancaChildPool), amount);
        amount = 22 * USDC_DECIMALS;

        s_lancaChildPool.completeRebalancing(ANY_BYTES32, amount);
        uint256 afterBalance = s_lancaChildPool.getUsdcLoansInUse();
        vm.assertEq(afterBalance, beforeBalance - amount);
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

        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notLancaBridge
            )
        );
        s_lancaChildPool.completeRebalancing(ANY_BYTES32, amount);
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
        bytes32 withdrawalRequestId = ANY_BYTES32;
        uint256 amountToSend = 1 * USDC_DECIMALS;

        s_lancaChildPool.exposed_setDstPoolByChainSelector(chainSelector, pool);
        s_lancaChildPool.exposed_setIsWithdrawalRequestTriggered(withdrawalRequestId, true);

        vm.prank(s_lancaChildPool.exposed_getMessengers()[0]);
        vm.expectRevert(ILancaPool.WithdrawalAlreadyTriggered.selector);
        s_lancaChildPool.ccipSendToPool(chainSelector, amountToSend, withdrawalRequestId);
    }

    function test_ccipSendToPool() public {
        uint64 chainSelector = 1;
        address pool = makeAddr("pool");
        bytes32 withdrawalRequestId = ANY_BYTES32;
        uint256 amountToSend = 10 * USDC_DECIMALS;

        s_lancaChildPool.exposed_setDstPoolByChainSelector(chainSelector, pool);
        deal(s_usdc, address(s_lancaChildPool), 10 * USDC_DECIMALS);
        uint256 beforeBalance = IERC20(s_usdc).balanceOf(address(s_lancaChildPool));
        vm.assertEq(beforeBalance, amountToSend);

        vm.prank(s_lancaChildPool.exposed_getMessengers()[0]);
        s_lancaChildPool.ccipSendToPool(chainSelector, amountToSend, withdrawalRequestId);
        uint256 afterBalance = IERC20(s_usdc).balanceOf(address(s_lancaChildPool));
        vm.assertEq(afterBalance, 0);
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

    function test_liquidatePoolForTwoPools() public {
        address pool1 = makeAddr("pool 1");
        address pool2 = makeAddr("pool 2");
        uint64 chain1Selector = 1;
        uint64 chain2Selector = 2;

        vm.prank(s_deployChildPoolHarnessScript.getDeployer());
        s_lancaChildPool.setDstPool(chain1Selector, pool1);
        vm.prank(s_deployChildPoolHarnessScript.getDeployer());
        s_lancaChildPool.setDstPool(chain2Selector, pool2);

        bytes32 distributeLiquidityRequestId = bytes32(0);
        deal(s_usdc, address(s_lancaChildPool), 1000 * USDC_DECIMALS);

        vm.prank(s_lancaChildPool.exposed_getMessengers()[0]);
        s_lancaChildPool.liquidatePool(distributeLiquidityRequestId);
        uint256 afterBalance = IERC20(s_usdc).balanceOf(address(s_lancaChildPool));
        vm.assertEq(afterBalance, 2);
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
    
    /* CCIP RECEIVE FROM ROUTER */

    function test_ccipReceiveSettlementWithoutExecutionLayerFails() public {
        address receiver0 = makeAddr("receiver 0");
        address receiver1 = makeAddr("receiver 1");
        address receiver2 = makeAddr("receiver 2");

        ILancaBridge.CcipSettlementTxs[]
        memory ccipSettlementTxs = new ILancaBridge.CcipSettlementTxs[](3);

        ccipSettlementTxs[0] = ILancaBridge.CcipSettlementTxs({
        id: keccak256("ccip settlement tx 0"),
        receiver: receiver0,
        amount: 100 * USDC_DECIMALS
        });

        ccipSettlementTxs[1] = ILancaBridge.CcipSettlementTxs({
        id: keccak256("ccip settlement tx 1"),
        receiver: receiver1,
        amount: 200 * USDC_DECIMALS
        });

        ccipSettlementTxs[2] = ILancaBridge.CcipSettlementTxs({
        id: keccak256("ccip settlement tx 2"),
        receiver: receiver2,
        amount: 300 * USDC_DECIMALS
        });

        ICcip.CcipSettleMessage memory ccipTxs = ICcip.CcipSettleMessage({
        ccipTxType: ICcip.CcipTxType.batchedSettlement,
        data: abi.encode(ccipSettlementTxs)
        });

        LibCcipClient.EVMTokenAmount[] memory destTokenAmounts = new LibCcipClient.EVMTokenAmount[](
            1
        );

        destTokenAmounts[0].token = s_usdc;

        uint256 beforeLancaPoolBalance = IERC20(s_usdc).balanceOf(
            address(s_lancaChildPool)
        );

        deal(s_usdc, address(s_lancaChildPool), destTokenAmounts[0].amount);

        address s_lancaBridgeArb = makeAddr("arb lanca bridge");
        uint64 chainSelector = 1;

        LibCcipClient.Any2EVMMessage memory ccipMessage = LibCcipClient.Any2EVMMessage({
            messageId: keccak256("ccip message id"),
            sourceChainSelector: chainSelector,
            sender: abi.encode(s_lancaBridgeArb),
            data: abi.encode(ccipTxs),
            destTokenAmounts: destTokenAmounts
        });

        vm.prank(s_lancaChildPool.getRouter());
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.Unauthorized.selector,
                LibErrors.UnauthorizedType.notAllowedSender
            )
        );
        s_lancaChildPool.ccipReceive(ccipMessage);

        s_lancaChildPool.exposed_setDstPoolByChainSelector(chainSelector, s_lancaBridgeArb);
        vm.prank(s_lancaChildPool.getRouter());
        s_lancaChildPool.ccipReceive(ccipMessage);

        uint256 afterLancaPoolBalance = IERC20(s_usdc).balanceOf(
            address(s_lancaChildPool)
        );

        assertEq(afterLancaPoolBalance, beforeLancaPoolBalance + destTokenAmounts[0].amount);
    }
}
