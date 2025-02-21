import { Deployment } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { conceroNetworks, networkEnvKeys } from "../constants/conceroNetworks"
import updateEnvVariable from "../utils/updateEnvVariable"
import log from "../utils/log"
import { getEnvVar } from "../utils"
import { getGasParameters } from "../utils/getGasPrice"
import {
    PARENT_POOL_MAINNET_WITHDRAWAL_COOLDOWN_SECONDS,
    PARENT_POOL_TESTNET_WITHDRAWAL_COOLDOWN_SECONDS,
    PARENT_POOL_CLF_SECRETS_SLOT_ID,
    viemReceiptConfig,
} from "../constants/deploymentVariables"
import { CNetworkNames } from "../types/CNetwork"
import { getHashSum } from "../utils/getHashSum"
import { ClfJsCodeType, getClfJsCode } from "../utils/getClfJsCode"

interface Args {
    lpToken: string
    usdc: string
    clfRouter: string
    clfSubId: string
    clfDonId: string
    clfSecretsSlotId: string
    clfSecretsVersion: string
    collectLiqJsHash: string
    ethersJsHash: string
    withdrawalCooldownSeconds: number
}

const deployParentPoolClfClfImplementation: (
    hre: HardhatRuntimeEnvironment,
    constructorArgs?: ConstructorArgs,
) => Promise<void> = async function (hre: HardhatRuntimeEnvironment, constructorArgs = {}) {
    const { proxyDeployer } = await hre.getNamedAccounts()
    const { deploy } = hre.deployments
    const { live } = hre.network
    const name = hre.network.name as CNetworkNames
    const cNetwork = conceroNetworks[name]
    const networkType = cNetwork.type
    const isTestnet = cNetwork.type === "testnet"

    const { functionsRouter, functionsSubIds, functionsDonId } = cNetwork
    const { maxFeePerGas, maxPriorityFeePerGas } = await getGasParameters(conceroNetworks[name])

    if (!functionsRouter || !functionsSubIds || !functionsSubIds[0] || !functionsDonId) {
        throw new Error(`No functionsRouter, functionsSubIds or functionsDonId found for ${name}`)
    }

    const defaultArgs: Args = {
        parentProxyAddress: getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[name]}`),
        lpToken: getEnvVar(`LPTOKEN_${networkEnvKeys[name]}`),
        usdc: getEnvVar(`USDC_${networkEnvKeys[name]}`),
        clfRouter: functionsRouter,
        clfSubId: functionsSubIds[0],
        clfDonId: functionsDonId,
        clfSecretsSlotId: PARENT_POOL_CLF_SECRETS_SLOT_ID,
        clfSecretsVersion: getEnvVar(`CLF_DON_SECRETS_VERSION_${networkEnvKeys[name]}`),
        collectLiqJsHash: getHashSum(await getClfJsCode(ClfJsCodeType.CollectLiq)),
        ethersJsHash: getHashSum(await getClfJsCode(ClfJsCodeType.EthersV6)),
        withdrawalCooldownSeconds: isTestnet
            ? PARENT_POOL_TESTNET_WITHDRAWAL_COOLDOWN_SECONDS
            : PARENT_POOL_MAINNET_WITHDRAWAL_COOLDOWN_SECONDS,
    }

    const args = { ...defaultArgs, ...constructorArgs }
    console.log("Deploying parent pool clf cla...")

    const deployParentPoolCLFCLA = (await deploy("LancaParentPoolCLFCLA", {
        from: proxyDeployer,
        args: [
            args.lpToken,
            args.usdc,
            args.clfRouter,
            args.clfSubId,
            args.clfDonId,
            args.clfSecretsSlotId,
            args.clfSecretsVersion,
            args.collectLiqJsHash,
            args.ethersJsHash,
            args.withdrawalCooldownSeconds,
        ],
        log: true,
        autoMine: true,
        gasLimit: 3_000_000,
        maxFeePerGas: maxFeePerGas.toString(),
        maxPriorityFeePerGas: maxPriorityFeePerGas.toString(),
        waitConfirmations: viemReceiptConfig.confirmations,
    })) as Deployment

    if (live) {
        log(`Parent pool clf cla deployed to ${name} to: ${deployParentPoolCLFCLA.address}`, "deployParentPoolCLFCLA")
        updateEnvVariable(
            `PARENT_POOL_CLF_CLA_${networkEnvKeys[name]}`,
            deployParentPoolCLFCLA.address,
            `deployments.${networkType}`,
        )
    }
}

export default deployParentPoolClfClfImplementation
deployParentPoolClfClfImplementation.tags = ["LancaParentPoolCLFCLA"]
