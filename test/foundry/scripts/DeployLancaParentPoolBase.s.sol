// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/proxy/TransparentUpgradeableProxy.sol";
import {Test} from "forge-std/src/Test.sol";
import {PauseDummy} from "contracts/common/PauseDummy.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {FunctionsSubscriptions} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsSubscriptions.sol";
import {DeployHelper} from "../utils/DeployHelper.sol";
import {Cheats} from "../scripts/DeployLancaBridgeBase.s.sol";

abstract contract DeployLancaParentPoolScriptBase is DeployHelper {
    /// @notice contract addresses
    TransparentUpgradeableProxy internal s_lancaParentPoolProxy;
    address internal s_lancaParentPool;
    Cheats internal s_cheats;

    /// @notice helper variables
    address internal s_proxyDeployer = vm.envAddress("PROXY_DEPLOYER");
    address internal s_deployer = vm.envAddress("DEPLOYER_ADDRESS");

    function run() public returns (address) {
        s_cheats = new Cheats();
        _deployFullLancaParentPool();
        return address(s_lancaParentPoolProxy);
    }
    function run(uint256 forkId) public returns (address) {
        vm.selectFork(forkId);
        return run();
    }

    /* SETTERS */

    function setProxyImplementation(address implementation) public {
        vm.prank(s_proxyDeployer);
        ITransparentUpgradeableProxy(address(s_lancaParentPoolProxy)).upgradeToAndCall(
            implementation,
            bytes("")
        );
    }

    /* GETTERS */

    function getLancaParentPool() public view returns (address) {
        return address(s_lancaParentPoolProxy);
    }

    function getDeployer() public view returns (address) {
        return s_deployer;
    }

    function getProxyDeployer() public view returns (address) {
        return s_proxyDeployer;
    }

    function getDonHostedSecretsSlotId() public pure returns (uint8) {
        return uint8(0);
    }

    function getLpTokenAddress() public pure returns (address) {}

    function getDonHostedSecretsVersion() public pure returns (uint64) {
        return uint64(0);
    }

    function getCLfDonId() public pure returns (bytes32) {
        return bytes32(0);
    }

    function getCLfDonVersion() public pure returns (uint64) {
        return uint64(0);
    }

    /* INTERNAL FUNCTIONS  */

    function _deployFullLancaParentPool() internal {
        _deployTransparentProxy();
        _deployAndSetImplementation();
        _addConsumerToClfSub(getLancaParentPool());
        _fundClfSubscription(10_000 * 1e18);
    }

    function _deployTransparentProxy() internal {
        vm.prank(s_proxyDeployer);
        s_lancaParentPoolProxy = new TransparentUpgradeableProxy(
            address(new PauseDummy()),
            s_proxyDeployer,
            ""
        );
    }

    function _deployAndSetImplementation() internal {
        _deployLancaParentPool();
        //vm.allowCheatcodes(address(s_lancaParentPoolProxy));
        //s_cheats.exposed_deal(getLinkAddress(), address(s_lancaParentPoolProxy), 1000e18);

        setProxyImplementation(address(s_lancaParentPool));
    }

    function _fundClfSubscription(uint256 amount) internal {
        //s_cheats.exposed_deal(getLinkAddress(), getDeployer(), amount);
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

    function _deployLancaParentPool() internal virtual;
}
