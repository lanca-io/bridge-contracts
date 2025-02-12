import { task } from "hardhat/config"
import { compileContracts } from "../../utils/compileContracts"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { CNetwork, CNetworkNames, NetworkType } from "../../types/CNetwork"
import { conceroNetworks } from "../../constants"
import { networkTypes } from "../../constants/conceroNetworks"
import { conceroChains } from "../../constants/liveChains"
import { verifyContractVariables } from "../verifyContractVariables.task"
import { parentPoolClfSecretsSlotId, ProxyEnum } from "../../constants/deploymentVariables"
import { upgradeProxyImplementation } from "../transparentProxy/upgradeProxyImplementation.task"
import deployParentPoolImplementation from "../../deploy/ParentPool"
import { setParentPoolVars } from "./setParentPoolVars"
import { uploadClfSecrets } from "../clf/uploadClfSecrets.task"
import deployParentPoolClfClfImplementation from "../../deploy/ParenPoolCLFCLA"
import { registerCustomUpkeep } from "./registerCustomUpkeep"
import { Address } from "viem"
import { getEnvAddress } from "../../utils/getEnvVar"

interface DeployInfraParams {
    hre: any
    liveChains: CNetwork[]
    deployableChains: CNetwork[]
    networkType: NetworkType
    deployProxy: boolean
    deployImplementation: boolean
    setVars: boolean
    uploadSecrets: boolean
}

async function deployParentPool(params: DeployInfraParams) {
    const { hre, deployProxy, deployImplementation, setVars, uploadSecrets } = params
    const name = hre.network.name as CNetworkNames

    if (deployProxy) {
        // await deployProxyAdmin(hre, ProxyEnum.parentPoolProxy)
        // await deployTransparentProxy(hre, ProxyEnum.parentPoolProxy)
        const [proxyAddress] = getEnvAddress(ProxyEnum.parentPoolProxy, name)
        // const { functionsSubIds } = conceroNetworks[name]
        // await addClfConsumer(conceroNetworks[name], [proxyAddress], functionsSubIds[0])
        await registerCustomUpkeep(hre, {
            linkTokenAddress: conceroNetworks[name].linkToken as Address,
            depositAmount: 0n,
            upkeepName: "parent-pool",
            upkeepContractAddress: proxyAddress,
            orcConfig: "0x",
            source: 0,
            data: "",
        })
    }

    if (uploadSecrets) {
        await uploadClfSecrets([conceroNetworks[name]], parentPoolClfSecretsSlotId)
    }

    if (deployImplementation) {
        await deployParentPoolClfClfImplementation(hre)
        await deployParentPoolImplementation(hre, params)
        await upgradeProxyImplementation(hre, ProxyEnum.parentPoolProxy, false)
    }

    if (setVars) {
        await setParentPoolVars()
    }
}

task("deploy-parent-pool", "Deploy the Lanca parent pool")
    .addFlag("deployproxy", "Deploy the proxy")
    .addFlag("deployimplementation", "Deploy the implementation")
    .addFlag("setvars", "Set the contract variables")
    .addFlag("uploadsecrets", "Upload the secrets")
    .setAction(async taskArgs => {
        compileContracts({ quiet: true })

        // eslint-disable-next-line @typescript-eslint/no-require-imports
        const hre: HardhatRuntimeEnvironment = require("hardhat")

        const { live } = hre.network
        const name = hre.network.name as CNetworkNames
        const networkType = conceroNetworks[name].type
        let deployableChains: CNetwork[] = []
        if (live) deployableChains = [conceroNetworks[name]]

        let liveChains: CNetwork[] = []
        if (networkType == networkTypes.mainnet) {
            liveChains = conceroChains.mainnet.parentPool
            await verifyContractVariables()
        } else {
            liveChains = conceroChains.testnet.parentPool
        }

        await deployParentPool({
            hre,
            deployableChains,
            liveChains,
            networkType,
            deployProxy: taskArgs.deployproxy,
            deployImplementation: taskArgs.deployimplementation,
            setVars: taskArgs.setvars,
            uploadSecrets: taskArgs.uploadsecrets,
        })
    })

export default {}
