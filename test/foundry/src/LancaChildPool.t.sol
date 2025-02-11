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

contract LancaChildPoolTest is Test {
    uint256 internal constant USDC_DECIMALS = 1e6;

    DeployLancaChildPoolHarnessScript internal s_deployChildPoolHarnessScript;
    LancaChildPoolHarness internal s_lancaChildPool;

    address internal s_usdc;

    function setUp() public {
        uint256 forkId = vm.createSelectFork(vm.envString("RPC_URL_BASE"), 26000933);
        s_deployChildPoolHarnessScript = new DeployLancaChildPoolHarnessScript();
        s_lancaChildPool = LancaChildPoolHarness(
            payable(s_deployChildPoolHarnessScript.run(forkId))
        );
        s_usdc = s_lancaChildPool.exposed_getUsdcToken();
    }

    function test_setPools() public {
        address pool = makeAddr("pool");
        uint64 chainSelector = 1;

        vm.prank(s_deployChildPoolHarnessScript.getDeployer());
        s_lancaChildPool.setPools(chainSelector, pool);

        vm.assertEq(s_lancaChildPool.exposed_getDstPoolByChainSelector(chainSelector), pool);
        vm.assertEq(s_lancaChildPool.exposed_getPoolChainSelectors()[0], chainSelector);
    }

    function test_removePools() public {
        uint64 chainSelector = 1;
        address pool = makeAddr("pool");

        vm.startPrank(s_deployChildPoolHarnessScript.getDeployer());
        s_lancaChildPool.setPools(chainSelector, pool);

        s_lancaChildPool.removePools(chainSelector);

        vm.assertEq(s_lancaChildPool.exposed_getPoolChainSelectors().length, 0);
        vm.assertEq(
            s_lancaChildPool.exposed_getDstPoolByChainSelector(chainSelector),
            ZERO_ADDRESS
        );
    }

    /// @dev check this test
    function test_distributeLiquidity() public {
        address messenger = s_lancaChildPool.exposed_getMessengers()[0];
        uint64 chainSelector = 1;
        uint256 amountToSend = 100 * USDC_DECIMALS;
        bytes32 distributeLiquidityRequestId = bytes32(0);
        address pool = makeAddr("pool");

        vm.prank(s_deployChildPoolHarnessScript.getDeployer());
        s_lancaChildPool.setPools(chainSelector, pool);

        deal(s_usdc, address(s_lancaChildPool), 1000 * USDC_DECIMALS);
        deal(s_usdc, messenger, 1000 * USDC_DECIMALS);
        deal(s_lancaChildPool.exposed_getLinkToken(), 1000 ether);

        vm.startPrank(messenger);

        s_lancaChildPool.distributeLiquidity(
            chainSelector,
            amountToSend,
            distributeLiquidityRequestId
        );

        vm.stopPrank();

        vm.assertEq(
            s_lancaChildPool.exposed_getDistributeLiquidityRequestProcessed(
                distributeLiquidityRequestId
            ),
            true
        );
        /// @dev fix _ccipSend approvals checks
        address ccipRouter = s_lancaChildPool.getRouter();
        uint256 allowance = IERC20(s_usdc).allowance(address(s_lancaChildPool), ccipRouter);
        vm.assertEq(allowance, amountToSend);
    }

    function test_takeLoan() public {
        deal(s_usdc, address(s_lancaChildPool), 1000 * USDC_DECIMALS);
        address receiver = makeAddr("receiver");
        uint256 amount = 100 * USDC_DECIMALS;

        vm.prank(s_lancaChildPool.exposed_getLancaBridge());
        s_lancaChildPool.takeLoan(s_usdc, amount, receiver);

        vm.assertEq(IERC20(s_usdc).balanceOf(receiver), amount);
        vm.assertEq(s_lancaChildPool.exposed_getLoansInUse(), amount);
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
        s_lancaChildPool.setPools(chainSelector, ZERO_ADDRESS);

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
        s_lancaChildPool.setPools(chainSelector, pool);

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
