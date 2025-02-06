// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {console} from "forge-std/src/console.sol";
import {LancaParentPool} from "contracts/pools/LancaParentPool.sol";
import {ILancaParentPool} from "contracts/pools/interfaces/ILancaParentPool.sol";
import {DeployLancaParentPoolHarnessScript} from "../../scripts/DeployLancaParentPoolHarness.s.sol";

contract LancaParentPoolTest is Test {
    DeployLancaParentPoolHarnessScript internal s_deployLancaParentPoolHarnessScript;
    LancaParentPoolMock internal s_lancaParentPool;
    address internal s_usdc = vm.envAddress("USDC_BASE");
    address internal depositor = makeAddr("depositor");

    uint256 internal constant USDC_DECIMALS = 1e6;
    uint256 internal constant DEPOSIT_AMOUNT = 100 * USDC_DECIMALS;

    modifier dealUsdcTo(address to, uint256 amount) {
        deal(s_usdc, to, amount);
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_URL_BASE"), 26000933);
        s_deployLancaParentPoolHarnessScript = new DeployLancaParentPoolHarnessScript();
        s_lancaParentPool = LancaParentPool(payable(s_deployLancaParentPoolHarnessScript.run()));
    }

    function test_lancaParentPoolStartDepositFailsWhenAmountToLow()
        external
        dealUsdcTo(depositor, 1 * USDC_DECIMALS)
    {
        vm.prank(depositor);
        vm.expectRevert(ILancaParentPool.DepositAmountBelowMinimum.selector);
        s_lancaParentPool.startDeposit(depositAmount);
    }

    function test_lancaParentPoolStartDepositFailsWhenMaxDepositCapReached()
        external
        dealUsdcTo(depositor, 100 * USDC_DECIMALS)
    {
        s_lancaParentPool.setLiquidityCap(1 * USDC_DECIMALS);

        vm.prank(depositor);
        vm.expectRevert(ILancaParentPool.MaxDepositCapReached.selector);
        s_lancaParentPool.startDeposit(depositAmount);  
    }

    function test_lancaParentPoolStartDepositSucceeds()
        external
        dealUsdcTo(depositor, 100 * USDC_DECIMALS)
    {
        uint256 
        vm.prank(depositor);

        bytes[] memory args = new bytes[](3);
        args[0] = abi.encodePacked(s_getChildPoolsLiquidityJsCodeHashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);
        args[2] = abi.encodePacked(CLFRequestType.startDeposit_getChildPoolsLiquidity);
        bytes32 clfRequestId = bytes32(args);

        vm.recordLogs();

        s_lancaParentPool.startDeposit(DEPOSIT_AMOUNT);

        assertEq(
            s_clfRequestTypes[clfRequestId],
            CLFRequestType.startDeposit_getChildPoolsLiquidity
        );
        assertEq(s_depositRequests[clfRequestId].lpAddress, depositor);
        assertEq(s_depositRequests[clfRequestId].usdcAmountToDeposit, DEPOSIT_AMOUNT);
        assertEq(s_depositRequests[clfRequestId].deadline, block.timestamp + DEPOSIT_DEADLINE_SECONDS);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics[0], keccak256("DepositInitiated(bytes32,address,uint256,uint256)"));

    }
}
