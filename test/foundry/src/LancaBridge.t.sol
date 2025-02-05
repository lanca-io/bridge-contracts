pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {DeployLancaBridgeHarnessScript} from "../scripts/DeployLancaBridgeHarness.s.sol";
import {LancaBridgeHarness} from "../harnesses/LancaBridgeHarness.sol";
import {console} from "forge-std/src/console.sol";
import {ILancaBridge} from "contracts/bridge/interfaces/ILancaBridge.sol";
import {LancaBridgeTestBase} from "./LancaBridgeBase.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LancaBridgeTest is LancaBridgeTestBase {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_bridge() public {
        address sender = makeAddr("sender");
        address receiver = makeAddr("receiver");
        address bridgeToken = s_usdc;
        uint64 dstChainSelector = s_chainSelectorArb;
        uint256 amount = 100 * USDC_DECIMALS;
        bytes memory message = new bytes(0);
        uint32 dstChainGasLimit = 1_000_000;

        deal(bridgeToken, sender, amount);

        vm.startPrank(sender);
        ILancaBridge.BridgeReq memory bridgeReq = ILancaBridge.BridgeReq({
            amount: amount,
            token: bridgeToken,
            feeToken: bridgeToken,
            receiver: receiver,
            fallbackReceiver: receiver,
            dstChainSelector: dstChainSelector,
            dstChainGasLimit: dstChainGasLimit,
            message: message
        });
        IERC20(bridgeToken).approve(address(s_lancaBridge), amount);
        s_lancaBridge.bridge(bridgeReq);
        vm.stopPrank();
    }
}
