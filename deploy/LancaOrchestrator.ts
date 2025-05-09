import { HardhatRuntimeEnvironment } from "hardhat/types"
import { getEnvVar } from "../utils"
import { conceroNetworks, networkEnvKeys } from "../constants/conceroNetworks"
import log from "../utils/log"
import { Deployment } from "hardhat-deploy/types"
import { getGasParameters } from "../utils/getGasPrice"
import { CNetworkNames } from "../types/CNetwork"
import updateEnvVariable from "../utils/updateEnvVariable"
import { viemReceiptConfig } from "../constants/deploymentVariables"

const deployLancaOrchestratorImplementation: (hre: HardhatRuntimeEnvironment) => Promise<void> = async function (
    hre: HardhatRuntimeEnvironment,
) {
    const { deployer } = await hre.getNamedAccounts()
    const { deploy } = hre.deployments
    const { live } = hre.network
    const name = hre.network.name as CNetworkNames
    const { type, chainSelector } = conceroNetworks[name]

    const args = {
        usdc: getEnvVar(`USDC_${networkEnvKeys[name]}`),
        lancaBridge: getEnvVar(`LANCA_BRIDGE_PROXY_${networkEnvKeys[name]}`),
        dexSwap: getEnvVar(`DEX_SWAP_${networkEnvKeys[name]}`),
        chainSelector,
    }

    const { maxFeePerGas, maxPriorityFeePerGas } = await getGasParameters(conceroNetworks[name])

    log("Deploying...", "deployLancaOrchestrator", name)

    const deployLancaOrchestrator = (await deploy("LancaOrchestrator", {
        from: deployer,
        args: [args.usdc, args.lancaBridge, args.dexSwap, args.chainSelector],
        log: true,
        autoMine: true,
        // maxFeePerGas: maxFeePerGas.toString(),
        // maxPriorityFeePerGas: maxPriorityFeePerGas.toString(),
        waitConfirmations: viemReceiptConfig.confirmations,
    })) as Deployment

    if (live) {
        log(`Deployed at: ${deployLancaOrchestrator.address}`, "deployLancaOrchestrator", name)
        updateEnvVariable(
            `LANCA_ORCHESTRATOR_${networkEnvKeys[name]}`,
            deployLancaOrchestrator.address,
            `deployments.${type}`,
        )
    }
}

export default deployLancaOrchestratorImplementation
deployLancaOrchestratorImplementation.tags = ["LancaOrchestrator"]
