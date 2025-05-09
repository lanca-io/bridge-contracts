import { Deployment } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { conceroNetworks, networkEnvKeys } from "../constants/conceroNetworks"
import updateEnvVariable from "../utils/updateEnvVariable"
import log from "../utils/log"
import { getEnvVar } from "../utils"
import { poolMessengers } from "../constants"
import { getGasParameters } from "../utils/getGasPrice"
import { CNetworkNames } from "../types/CNetwork"
import { viemReceiptConfig } from "../constants/deploymentVariables"

interface ConstructorArgs {
    conceroProxyAddress?: string
    parentProxyAddress?: string
    childProxyAddress?: string
    linkToken?: string
    ccipRouter?: string
    chainSelector?: number
    usdc?: string
    owner?: string
    messengers?: string[]
}

const deployChildPoolImplementation: (
    hre: HardhatRuntimeEnvironment,
    constructorArgs?: ConstructorArgs,
) => Promise<void> = async function (hre: HardhatRuntimeEnvironment, constructorArgs: ConstructorArgs = {}) {
    const { deployer } = await hre.getNamedAccounts()
    const { deploy } = hre.deployments
    const { live } = hre.network
    const name = hre.network.name as CNetworkNames
    const { linkToken, ccipRouter, type } = conceroNetworks[name]

    const defaultArgs = {
        linkToken: linkToken,
        ccipRouter: ccipRouter,
        usdc: getEnvVar(`USDC_${networkEnvKeys[name]}`),
        owner: deployer,
        lancaBridge: getEnvVar(`LANCA_BRIDGE_PROXY_${networkEnvKeys[name]}`),
        poolMessengers,
    }

    const args = { ...defaultArgs, ...constructorArgs }
    const { maxFeePerGas, maxPriorityFeePerGas } = await getGasParameters(conceroNetworks[name])

    log("Deploying...", "deployChildPool", name)

    const deployChildPool = (await deploy("LancaChildPool", {
        from: deployer,
        args: [args.owner, args.usdc, args.linkToken, args.lancaBridge, args.ccipRouter, args.poolMessengers],
        log: true,
        autoMine: true,
        maxFeePerGas,
        maxPriorityFeePerGas,
        waitConfirmations: viemReceiptConfig.confirmations,
    })) as Deployment

    if (live) {
        log(`Deployed at: ${deployChildPool.address}`, "deployConceroChildPool", name)
        updateEnvVariable(`CHILD_POOL_${networkEnvKeys[name]}`, deployChildPool.address, `deployments.${type}`)
    }
}

export default deployChildPoolImplementation
deployChildPoolImplementation.tags = ["LancaChildPool"]
