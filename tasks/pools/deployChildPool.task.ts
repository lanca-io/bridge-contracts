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
import deployChildPoolImplementation from "../../deploy/ChildPool"
import { setChildPoolVars } from "./setChildPoolVars"

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

async function deployChildPool(params: DeployInfraParams) {
    const { hre, deployableChains, deployProxy, deployImplementation, setVars } = params
    const name = hre.network.name as CNetworkNames

    if (deployProxy) {
        await deployProxyAdmin(hre, ProxyEnum.childPool)
        await deployTransparentProxy(hre, ProxyEnum.childPool)
    }

    if (deployImplementation) {
        await deployChildPoolImplementation(hre)
        await upgradeProxyImplementation(hre, ProxyEnum.childPool, false)
    }

    if (setVars) {
        await setChildPoolVars(deployableChains[0])
    }
}

task("deploy-child-pool", "Deploy the Lanca child pool")
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
            liveChains = conceroChains.mainnet.childPool
            await verifyContractVariables()
        } else {
            liveChains = conceroChains.testnet.childPool
        }

        await deployChildPool({
            hre,
            deployableChains,
            liveChains,
            networkType,
            deployProxy: taskArgs.deployproxy,
            deployImplementation: taskArgs.deployimplementation,
            setVars: taskArgs.setvars,
        })
    })

export default {}
