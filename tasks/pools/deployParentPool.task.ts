import { task } from "hardhat/config"
import { compileContracts } from "../../utils/compileContracts"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { CNetwork, CNetworkNames, NetworkType } from "../../types/CNetwork"
import { conceroNetworks } from "../../constants"
import { networkTypes } from "../../constants/conceroNetworks"
import { conceroChains } from "../../constants/liveChains"
import { verifyContractVariables } from "../verifyContractVariables.task"
import deployProxyAdmin from "../../deploy/TransparentProxyAdmin"
import deployTransparentProxy from "../../deploy/TransparentProxy"
import { ProxyEnum } from "../../constants/deploymentVariables"
import { upgradeProxyImplementation } from "../transparentProxy/upgradeProxyImplementation.task"
import { getEnvAddress } from "../../utils/getEnvVar"
import { addClfConsumer } from "../clf/addClfConsumer.task"
import deployParentPoolImplementation from "../../deploy/ParentPool"
import { setParentPoolVars } from "./setParentPoolVars"

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
    const { hre, deployableChains, deployProxy, deployImplementation, setVars } = params
    const name = hre.network.name as CNetworkNames

    if (deployProxy) {
        await deployProxyAdmin(hre, ProxyEnum.conceroRouterProxy)
        await deployTransparentProxy(hre, ProxyEnum.conceroRouterProxy)
        const [proxyAddress] = getEnvAddress(ProxyEnum.parentPoolProxy, name)
        const { functionsSubIds } = conceroNetworks[name]
        await addClfConsumer(conceroNetworks[name], [proxyAddress], functionsSubIds[0])
    }

    if (deployImplementation) {
        await deployParentPoolImplementation(hre, params)
        await upgradeProxyImplementation(hre, ProxyEnum.parentPool, false)
    }

    if (setVars) {
        await setParentPoolVars()
    }
}

task("deploy-parent-pool", "Deploy the Lanca parent pool")
    .addFlag("deployproxy", "Deploy the proxy")
    .addFlag("deployimplementation", "Deploy the implementation")
    .addFlag("setvars", "Set the contract variables")
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
