// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {DeployLancaBridgeHarnessScript} from "../scripts/DeployLancaBridgeHarness.s.sol";
import {LancaParentPoolHarness} from "../harnesses/LancaParentPoolHarness.sol";
import {LancaParentPoolCLFCLA} from "contracts/pools/LancaParentPoolCLFCLA.sol";
import {LancaParentPool} from "contracts/pools/LancaParentPool.sol";
import {DeployBase} from "./DeployBase.s.sol";

contract DeployLancaParentPoolHarnessScript is DeployBase {
    function _deployImplementation() internal override returns (address) {
        LancaParentPool.TokenConfig memory tokenConfig = LancaParentPool.TokenConfig({
            link: getLinkAddress(),
            usdc: getUsdcAddress(),
            lpToken: makeAddr("lpToken")
        });

        address[3] memory messengers = [getMessengers()[0], getMessengers()[1], getMessengers()[2]];

        vm.startPrank(getDeployer());
        LancaParentPool.AddressConfig memory addressConfig = LancaParentPool.AddressConfig({
            ccipRouter: getCcipRouter(),
            automationForwarder: makeAddr("automation forwarder"),
            parentPoolProxy: makeAddr("parent pool proxy"),
            owner: getDeployer(),
            lancaParentPoolCLFCLA: address(
                new LancaParentPoolCLFCLA(
                    tokenConfig.lpToken,
                    tokenConfig.usdc,
                    makeAddr("lancaBridge"),
                    getClfRouter(),
                    getCLfSubId(),
                    getClfDonId(),
                    getClfSecretsSlotId(),
                    getClfSecretsVersion(),
                    keccak256("distributeLiquidityJs")
                )
            ),
            clfRouter: getClfRouter(),
            lancaBridge: makeAddr("lancaBridge"),
            messengers: messengers
        });

        LancaParentPool.HashConfig memory hashConfig = LancaParentPool.HashConfig({
            distributeLiquidityJs: bytes32(0)
        });
        address lancaParentPool = address(
            new LancaParentPoolHarness(tokenConfig, addressConfig, hashConfig)
        );

        vm.stopPrank();

        return lancaParentPool;
    }
}
