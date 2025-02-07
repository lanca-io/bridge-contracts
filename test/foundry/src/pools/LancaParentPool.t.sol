// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {Vm} from "forge-std/src/Vm.sol";
import {console} from "forge-std/src/console.sol";
import {LancaParentPool} from "contracts/pools/LancaParentPool.sol";
import {ILancaParentPool} from "contracts/pools/interfaces/ILancaParentPool.sol";
import {DeployLancaParentPoolHarnessScript} from "../../scripts/DeployLancaParentPoolHarness.s.sol";
import {LancaParentPoolMock} from "../../mocks/LancaParentPoolMock.sol";
import {LancaParentPoolCLFCLAMock} from "../../mocks/LancaParentPoolCLFCLA.sol";

contract LancaParentPoolTest is Test {
    DeployLancaParentPoolHarnessScript internal s_deployLancaParentPoolHarnessScript;
    LancaParentPoolMock internal s_lancaParentPool;
    address internal s_usdc = vm.envAddress("USDC_BASE");
    address internal depositor = makeAddr("depositor");

    uint256 internal constant USDC_DECIMALS = 1e6;
    uint256 internal constant DEPOSIT_AMOUNT = 100 * USDC_DECIMALS;
    uint256 internal constant LOW_DEPOSIT_AMOUNT = 1 * USDC_DECIMALS;
    uint256 internal constant DEPOSIT_DEADLINE_SECONDS = 60;

    modifier dealUsdcTo(address to, uint256 amount) {
        deal(s_usdc, to, amount);
        _;
    }

    function setUp() public {
        uint256 forkId = vm.createSelectFork(vm.envString("RPC_URL_BASE"), 26000933);
        s_deployLancaParentPoolHarnessScript = new DeployLancaParentPoolHarnessScript();
        s_lancaParentPool = LancaParentPoolMock(
            payable(s_deployLancaParentPoolHarnessScript.run(forkId))
        );
    }

    /* DEPOSIT TESTS */

    function test_lancaParentPoolStartDepositFailsWhenAmountToLow()
        external
        dealUsdcTo(depositor, LOW_DEPOSIT_AMOUNT)
    {
        vm.prank(depositor);
        vm.expectRevert(ILancaParentPool.DepositAmountBelowMinimum.selector);
        s_lancaParentPool.startDeposit(LOW_DEPOSIT_AMOUNT);
    }

    function test_lancaParentPoolStartDepositFailsWhenMaxDepositCapReached()
        external
        dealUsdcTo(depositor, 100 * USDC_DECIMALS)
    {
        s_lancaParentPool.setLiquidityCap(LOW_DEPOSIT_AMOUNT);

        vm.prank(depositor);
        vm.expectRevert(ILancaParentPool.MaxDepositCapReached.selector);
        s_lancaParentPool.startDeposit(DEPOSIT_AMOUNT);
    }

    function test_lancaParentPoolStartDepositSucceeds()
        external
        dealUsdcTo(depositor, 100 * USDC_DECIMALS)
    {
        vm.prank(depositor);

        bytes[] memory args = new bytes[](3);
        args[0] = abi.encodePacked(bytes32(0));
        args[1] = abi.encodePacked(bytes32(0));
        args[2] = abi.encodePacked(
            ILancaParentPool.CLFRequestType.startDeposit_getChildPoolsLiquidity
        );
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            LancaParentPoolCLFCLAMock.sendCLFRequest.selector,
            args
        );
        bytes32 clfRequestId = bytes32(delegateCallArgs);

        vm.recordLogs();

        s_lancaParentPool.startDeposit(DEPOSIT_AMOUNT);

        assertEq(
            uint8(s_lancaParentPool.s_clfRequestTypes(clfRequestId)),
            uint8(ILancaParentPool.CLFRequestType.startDeposit_getChildPoolsLiquidity)
        );

        (
            address lpAddress,
            uint256 usdcAmountToDeposit,
            uint256 childPoolsLiquiditySnapshot,
            uint256 deadline
        ) = s_lancaParentPool.s_depositRequests(clfRequestId);

        assertEq(lpAddress, depositor);
        assertEq(usdcAmountToDeposit, DEPOSIT_AMOUNT);
        assertEq(deadline, block.timestamp + DEPOSIT_DEADLINE_SECONDS);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(
            entries[0].topics[0],
            keccak256("DepositInitiated(bytes32,address,uint256,uint256)")
        );

        // @dev check that the deposit request was sent to the CLF
        address lancaParentPoolCLFCLA = s_lancaParentPool.getParentPoolCLFCLA();

        args[0] = abi.encodePacked(clfRequestId);
        args[1] = bytes32(0);
        args[2] = bytes32(0);
        delegateCallArgs = abi.encodeWithSelector(
            LancaParentPoolCLFCLAMock.fulfillRequest.selector,
            args
        );

        LibLanca.safeDelegateCall(lancaParentPoolCLFCLA, delegateCallArgs);
    }

    /* WITHDRAWAL TESTS */
}
