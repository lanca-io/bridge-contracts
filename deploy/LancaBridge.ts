import { HardhatRuntimeEnvironment } from "hardhat/types"
import { getEnvVar } from "../utils"
import { conceroNetworks, networkEnvKeys } from "../constants/conceroNetworks"
import log from "../utils/log"
import { Deployment } from "hardhat-deploy/types"
import { getGasParameters } from "../utils/getGasPrice"
import { CNetworkNames } from "../types/CNetwork"
import updateEnvVariable from "../utils/updateEnvVariable"
import {
    LANCA_BRIDGE_MAINNET_BATCHED_TX_THRESHOLD,
    LANCA_BRIDGE_TESTNET_BATCHED_TX_THRESHOLD,
    viemReceiptConfig,
} from "../constants/deploymentVariables"

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

const deployLancaBridgeImplementation: (
    hre: HardhatRuntimeEnvironment,
    constructorArgs?: ConstructorArgs,
) => Promise<void> = async function (hre: HardhatRuntimeEnvironment, constructorArgs: ConstructorArgs = {}) {
    const { deployer } = await hre.getNamedAccounts()
    const { deploy } = hre.deployments
    const { live } = hre.network
    const name = hre.network.name as CNetworkNames
    const { type, chainSelector, linkToken } = conceroNetworks[name]
    const isTestnet = type === "testnet"
    const lancaPool =
        name === "base" || name === "baseSepolia"
            ? getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[name]}`)
            : getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[name]}`)
    const defaultArgs = {
        chainSelector,
        usdc: getEnvVar(`USDC_${networkEnvKeys[name]}`),
        conceroRouter: getEnvVar(`CONCERO_ROUTER_PROXY_${networkEnvKeys[name]}`),
        ccipRouter: getEnvVar(`CL_CCIP_ROUTER_${networkEnvKeys[name]}`),
        linkToken,
        lancaPool,
        batchedTxThreshold: isTestnet
            ? LANCA_BRIDGE_TESTNET_BATCHED_TX_THRESHOLD
            : LANCA_BRIDGE_MAINNET_BATCHED_TX_THRESHOLD,
    }

    const args = { ...defaultArgs, ...constructorArgs }
    const { maxFeePerGas, maxPriorityFeePerGas } = await getGasParameters(conceroNetworks[name])

    log("Deploying...", "deployLancaBridge", name)

    const deployLancaBridge = (await deploy("LancaBridge", {
        from: deployer,
        args: [
            args.conceroRouter,
            args.ccipRouter,
            args.usdc,
            args.linkToken,
            args.lancaPool,
            args.chainSelector,
            args.batchedTxThreshold,
        ],
        log: true,
        autoMine: true,
        // maxFeePerGas: maxFeePerGas.toString(),
        // maxPriorityFeePerGas: maxPriorityFeePerGas.toString(),
        waitConfirmations: viemReceiptConfig.confirmations,
    })) as Deployment

    if (live) {
        log(`Deployed at: ${deployLancaBridge.address}`, "deployLancaBridge", name)
        updateEnvVariable(`LANCA_BRIDGE_${networkEnvKeys[name]}`, deployLancaBridge.address, `deployments.${type}`)
    }
}

export default deployLancaBridgeImplementation
deployLancaBridgeImplementation.tags = ["LancaBridge"]
