// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/proxy/TransparentUpgradeableProxy.sol";
import {DeployHelper} from "../utils/DeployHelper.sol";
import {PauseDummy} from "contracts/common/PauseDummy.sol";
import {Test} from "forge-std/src/Test.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {FunctionsSubscriptions} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsSubscriptions.sol";
import {TestHarness} from "../harnesses/TestHarness.sol";

abstract contract DeployBase is DeployHelper {
    // @dev contract addresses
    TransparentUpgradeableProxy internal s_proxy;

    // @dev helper variables
    address internal s_proxyDeployer = vm.envAddress("PROXY_DEPLOYER");
    address internal s_deployer = vm.envAddress("DEPLOYER_ADDRESS");

    /* RUN */

    function run() public returns (address) {
        _deployProxyAndImplementation();
        return address(s_proxy);
    }

    function run(uint256 forkId) public returns (address) {
        vm.selectFork(forkId);
        return run();
    }

    /* SETTERS */

    function setProxyImplementation(address implementation) public {
        vm.prank(s_proxyDeployer);
        ITransparentUpgradeableProxy(address(s_proxy)).upgradeToAndCall(implementation, bytes(""));
    }

    /* GETTERS */

    function getProxy() public view returns (address) {
        return address(s_proxy);
    }

    function getDeployer() public view returns (address) {
        return s_deployer;
    }

    function getProxyDeployer() public view returns (address) {
        return s_proxyDeployer;
    }

    /* INTERNAL FUNCTIONS  */

    function _deployProxyAndImplementation() internal {
        _deployTransparentProxy();
        _deployAndSetImplementation();
        _addConsumerToClfSub(getProxy());
        _fundClfSubscription(10_000 * 1e18);
    }

    function _deployTransparentProxy() internal {
        vm.prank(s_proxyDeployer);
        s_proxy = new TransparentUpgradeableProxy(address(new PauseDummy()), s_proxyDeployer, "");
    }

    function _deployAndSetImplementation() internal {
        address implementation = _deployImplementation();

        TestHarness cheats = new TestHarness();
        cheats.exposed_deal(getLinkAddress(), address(s_proxy), 1000e18);

        setProxyImplementation(address(implementation));
    }

    function _fundClfSubscription(uint256 amount) internal {
        TestHarness cheats = new TestHarness();
        cheats.exposed_deal(getLinkAddress(), getDeployer(), amount);
        vm.prank(getDeployer());

        LinkTokenInterface(getLinkAddress()).transferAndCall(
            getClfRouter(),
            amount,
            abi.encode(getCLfSubId())
        );
    }

    function _addConsumerToClfSub(address consumer) internal {
        FunctionsSubscriptions functionsSubscriptions = FunctionsSubscriptions(getClfRouter());
        vm.prank(getDeployer());
        functionsSubscriptions.addConsumer(getCLfSubId(), consumer);
    }

    /* VIRTUAL FUNCTIONS */

    function _deployImplementation() internal virtual returns (address);
}
