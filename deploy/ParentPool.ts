import { Deployment } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { conceroNetworks, networkEnvKeys } from "../constants/conceroNetworks"
import updateEnvVariable from "../utils/updateEnvVariable"
import log from "../utils/log"
import { getEnvVar } from "../utils"
import { poolMessengers } from "../constants"
import { getGasParameters } from "../utils/getGasPrice"
import { CNetworkNames } from "../types/CNetwork"
import { getHashSum } from "../utils/getHashSum"
import { ClfJsCodeType, getClfJsCode } from "../utils/getClfJsCode"
import { parseUnits } from "viem"
import { viemReceiptConfig } from "../constants/deploymentVariables"

const deployParentPoolImplementation: (
    hre: HardhatRuntimeEnvironment,
    constructorArgs?: ConstructorArgs,
) => Promise<void> = async function (hre: HardhatRuntimeEnvironment, constructorArgs = {}) {
    const { deployer } = await hre.getNamedAccounts()
    const { deploy } = hre.deployments
    const { live } = hre.network
    const name = hre.network.name as CNetworkNames
    const isTestnet = conceroNetworks[name].type === "testnet"
    const networkType = conceroNetworks[name].type
    const { linkToken, ccipRouter, functionsRouter } = conceroNetworks[name]

    const defaultArgs = {
        tokenConfig: {
            link: linkToken,
            usdc: getEnvVar(`USDC_${networkEnvKeys[name]}`),
            lpToken: getEnvVar(`LPTOKEN_${networkEnvKeys[name]}`),
        },
        addressConfig: {
            ccipRouter: ccipRouter,
            automationForwarder: getEnvVar(`PARENT_POOL_AUTOMATION_FORWARDER_${networkEnvKeys[name]}`),
            owner: deployer,
            lancaParentPoolCLFCLA: getEnvVar(`PARENT_POOL_CLF_CLA_${networkEnvKeys[name]}`),
            lancaBridge: getEnvVar(`LANCA_BRIDGE_PROXY_${networkEnvKeys[name]}`),
            clfRouter: functionsRouter,
            messengers: poolMessengers,
        },
        hashConfig: {
            distributeLiquidityJs: getHashSum(await getClfJsCode(ClfJsCodeType.RedistributeLiq)),
            ethersJs: getHashSum(await getClfJsCode(ClfJsCodeType.EthersV6)),
            getChildPoolsLiquidityJsCodeHashSum: getHashSum(await getClfJsCode(ClfJsCodeType.GetChildPoolsLiq)),
        },
        poolConfig: {
            minDepositAmount: isTestnet ? parseUnits("1", 6) : parseUnits("250", 6),
            depositFeeAmount: isTestnet ? parseUnits("0", 6) : parseUnits("3", 6),
        },
    }

    const args = { ...defaultArgs, ...constructorArgs }
    const { maxFeePerGas, maxPriorityFeePerGas } = await getGasParameters(conceroNetworks[name])

    log("Deploying...", `deployParentPool, ${deployer}`, name)

    const deployParentPool = (await deploy("LancaParentPool", {
        from: deployer,
        args: [args.tokenConfig, args.addressConfig, args.hashConfig, args.poolConfig],
        log: true,
        autoMine: true,
        gasLimit: 4_000_000,
        maxFeePerGas,
        maxPriorityFeePerGas,
        waitConfirmations: viemReceiptConfig.confirmations,
    })) as Deployment

    if (live) {
        log(`Deployed at: ${deployParentPool.address}`, "deployParentPool", name)
        updateEnvVariable(`PARENT_POOL_${networkEnvKeys[name]}`, deployParentPool.address, `deployments.${networkType}`)
    }
}

export default deployParentPoolImplementation
deployParentPoolImplementation.tags = ["LancaParentPool"]
