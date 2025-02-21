import { HardhatRuntimeEnvironment } from "hardhat/types"
import { conceroNetworks, networkEnvKeys } from "../constants/conceroNetworks"
import log from "../utils/log"
import { Deployment } from "hardhat-deploy/types"
import { getGasParameters } from "../utils/getGasPrice"
import { CNetworkNames } from "../types/CNetwork"
import updateEnvVariable from "../utils/updateEnvVariable"
import { viemReceiptConfig } from "../constants/deploymentVariables"

const deployDexSwap: (hre: HardhatRuntimeEnvironment) => Promise<void> = async function (
    hre: HardhatRuntimeEnvironment,
) {
    const { deployer } = await hre.getNamedAccounts()
    const { deploy } = hre.deployments
    const { live } = hre.network
    const name = hre.network.name as CNetworkNames
    const { type, chainSelector } = conceroNetworks[name]

    const { maxFeePerGas, maxPriorityFeePerGas } = await getGasParameters(conceroNetworks[name])

    log("Deploying...", "deployDexSwap", name)

    const deployLancaOrchestrator = (await deploy("DexSwap", {
        from: deployer,
        args: [],
        log: true,
        autoMine: true,
        maxFeePerGas: maxFeePerGas.toString(),
        maxPriorityFeePerGas: maxPriorityFeePerGas.toString(),
        waitConfirmations: viemReceiptConfig.confirmations,
    })) as Deployment

    if (live) {
        log(`Deployed at: ${deployLancaOrchestrator.address}`, "deployLancaOrchestrator", name)
        updateEnvVariable(`DEX_SWAP_${networkEnvKeys[name]}`, deployLancaOrchestrator.address, `deployments.${type}`)
    }
}

export default deployDexSwap
deployDexSwap.tags = ["DexSwap"]
