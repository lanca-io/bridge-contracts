// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/proxy/TransparentUpgradeableProxy.sol";
import {DeployHelper} from "../utils/DeployHelper.sol";
import {PauseDummy} from "contracts/common/PauseDummy.sol";
import {Test} from "forge-std/src/Test.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {FunctionsSubscriptions} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsSubscriptions.sol";

contract Cheats is Test {
    function exposed_deal(address token, address to, uint256 amount) public {
        deal(token, to, amount);
    }
}

abstract contract DeployLancaBridgeScriptBase is DeployHelper {
    // @notice contract addresses
    TransparentUpgradeableProxy internal s_lancaBridgeProxy;
    address internal s_lancaBridge;

    // @notice helper variables
    address internal s_proxyDeployer = vm.envAddress("PROXY_DEPLOYER");
    address internal s_deployer = vm.envAddress("DEPLOYER_ADDRESS");

    /* RUN */

    function run() public returns (address) {
        _deployFullLancaBridge();
        return address(s_lancaBridgeProxy);
    }

    function run(uint256 forkId) public returns (address) {
        vm.selectFork(forkId);
        return run();
    }

    /* SETTERS */

    function setProxyImplementation(address implementation) public {
        vm.prank(s_proxyDeployer);
        ITransparentUpgradeableProxy(address(s_lancaBridgeProxy)).upgradeToAndCall(
            implementation,
            bytes("")
        );
    }

    /* GETTERS */

    function getLancaBridge() public view returns (address) {
        return address(s_lancaBridgeProxy);
    }

    function getDeployer() public view returns (address) {
        return s_deployer;
    }

    function getProxyDeployer() public view returns (address) {
        return s_proxyDeployer;
    }

    /* INTERNAL FUNCTIONS  */

    function _deployFullLancaBridge() internal {
        _deployTransparentProxy();
        _deployAndSetImplementation();
        _addConsumerToClfSub(getLancaBridge());
        _fundClfSubscription(10_000 * 1e18);
    }

    function _deployTransparentProxy() internal {
        vm.prank(s_proxyDeployer);
        s_lancaBridgeProxy = new TransparentUpgradeableProxy(
            address(new PauseDummy()),
            s_proxyDeployer,
            ""
        );
    }

    function _deployAndSetImplementation() internal {
        _deployLancaBridge();

        Cheats cheats = new Cheats();
        cheats.exposed_deal(getLinkAddress(), address(s_lancaBridgeProxy), 1000e18);

        setProxyImplementation(address(s_lancaBridge));
    }

    function _fundClfSubscription(uint256 amount) internal {
        Cheats cheats = new Cheats();
        cheats.exposed_deal(getLinkAddress(), getDeployer(), amount);
        vm.prank(getDeployer());

        LinkTokenInterface(getLinkAddress()).transferAndCall(
            getClfRouter(),
            amount,
            abi.encode(getCLfSubId())
        );
    }

    function _addConsumerToClfSub(address consumer) internal {
        FunctionsSubscriptions functionsSubscriptions = FunctionsSubscriptions(
            address(vm.envAddress("CLF_ROUTER_BASE"))
        );

        vm.prank(vm.envAddress("DEPLOYER_ADDRESS"));
        functionsSubscriptions.addConsumer(getCLfSubId(), consumer);
    }

    /* VIRTUAL FUNCTIONS */

    function _deployLancaBridge() internal virtual;
}
