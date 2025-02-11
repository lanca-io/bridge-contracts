// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {DeployLancaBridgeHarnessScript} from "../scripts/DeployLancaBridgeHarness.s.sol";
import {LancaParentPoolHarness} from "../harnesses/LancaParentPoolHarness.sol";
import {LancaParentPoolCLFCLA} from "contracts/pools/LancaParentPoolCLFCLA.sol";
import {LancaParentPool} from "contracts/pools/LancaParentPool.sol";
import {DeployBase} from "./DeployBase.s.sol";
import {LPToken} from "contracts/pools/LPToken.sol";

contract DeployLancaParentPoolHarnessScript is DeployBase {
    function _deployImplementation() internal override returns (address) {
        vm.startPrank(getDeployer());

        address[3] memory messengers = [getMessengers()[0], getMessengers()[1], getMessengers()[2]];
        LancaParentPool.TokenConfig memory tokenConfig = LancaParentPool.TokenConfig({
            link: getLinkAddress(),
            usdc: getUsdcAddress(),
            lpToken: address(new LPToken(getProxyDeployer(), getProxy()))
        });
        LancaParentPool.AddressConfig memory addressConfig = LancaParentPool.AddressConfig({
            ccipRouter: getCcipRouter(),
            automationForwarder: makeAddr("automation forwarder"),
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
                    // @dev doesn't matter for forge tests
                    keccak256("distributeLiquidityJs"),
                    // @dev doesn't matter for forge tests
                    keccak256("ethersJs"),
                    getWithdrawalCooldownSeconds()
                )
            ),
            clfRouter: getClfRouter(),
            lancaBridge: makeAddr("lancaBridge"),
            messengers: messengers
        });
        // @dev doesn't matter for forge tests
        LancaParentPool.HashConfig memory hashConfig = LancaParentPool.HashConfig({
            distributeLiquidityJs: bytes32(0),
            ethersJs: bytes32(0),
            getChildPoolsLiquidityJsCodeHashSum: bytes32(0)
        });
        LancaParentPool.PoolConfig memory poolConfig = LancaParentPool.PoolConfig({
            minDepositAmount: getMinDepositAmount(),
            depositFeeAmount: getDepositFeeAmount()
        });

        address lancaParentPool = address(
            new LancaParentPoolHarness(tokenConfig, addressConfig, hashConfig, poolConfig)
        );

        vm.stopPrank();

        return lancaParentPool;
    }
}
