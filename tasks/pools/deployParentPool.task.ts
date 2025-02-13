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
import { registerCustomUpkeep, RegistrationParams } from "./registerCustomUpkeep"
import { getEnvAddress } from "../../utils/getEnvVar"
import { Address, parseEther } from "viem"

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
    const { linkToken } = conceroNetworks[name]
    const { deployer } = hre.getNamedAccounts()

    if (deployProxy) {
        // await deployProxyAdmin(hre, ProxyEnum.parentPoolProxy)
        // await deployTransparentProxy(hre, ProxyEnum.parentPoolProxy)
        const [proxyAddress] = getEnvAddress(ProxyEnum.parentPoolProxy, name)
        // const { functionsSubIds } = conceroNetworks[name]
        // await addClfConsumer(conceroNetworks[name], [proxyAddress], functionsSubIds[0])

        const args: RegistrationParams = {
            upkeepContract: proxyAddress.toLowerCase() as Address,
            amount: parseEther("0.1"),
            adminAddress: deployer,
            gasLimit: 500_000,
            triggerType: 0,
            billingToken: linkToken?.toLowerCase() as Address,
            name: "parent-pool",
            encryptedEmail: "0x",
            checkData: "0x",
            triggerConfig: "0x",
            offchainConfig: "0x",
        }

        await registerCustomUpkeep(hre, args)
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
