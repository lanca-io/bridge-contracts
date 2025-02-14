import { task } from "hardhat/config"
import { compileContracts } from "../../utils/compileContracts"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { CNetwork, CNetworkNames, NetworkType } from "../../types/CNetwork"
import { conceroNetworks } from "../../constants"
import { networkTypes } from "../../constants/conceroNetworks"
import { conceroChains } from "../../constants/liveChains"
import { verifyContractVariables } from "../verifyContractVariables.task"
import deployTransparentProxy from "../../deploy/TransparentProxy"
import { ProxyEnum } from "../../constants/deploymentVariables"
import deployLancaBridgeImplementation from "../../deploy/LancaBridge"
import { upgradeProxyImplementation } from "../transparentProxy/upgradeProxyImplementation.task"
import { setLancaBridgeVars } from "./setLancaBridgeVars"
import deployProxyAdmin from "../../deploy/TransparentProxyAdmin"
import { handleError } from "../../utils/handleError"

interface DeployInfraParams {
    hre: any
    liveChains: CNetwork[]
    deployableChains: CNetwork[]
    networkType: NetworkType
    deployProxy: boolean
    deployImplementation: boolean
    setVars: boolean
    uploadSecrets: boolean
    slotId: number
}

async function deployLancaBridge(params: DeployInfraParams) {
    const { hre, deployableChains, deployProxy, deployImplementation, setVars } = params
    const name = hre.network.name as CNetworkNames
    const isTestnet = deployableChains[0].type === "testnet"

    if (deployProxy) {
        await deployProxyAdmin(hre, ProxyEnum.lancaBridgeProxy)
        await deployTransparentProxy(hre, ProxyEnum.lancaBridgeProxy)
    }

    if (deployImplementation) {
        await deployLancaBridgeImplementation(hre, params)
        await upgradeProxyImplementation(hre, ProxyEnum.lancaBridgeProxy, false)
    }

    if (setVars) {
        await setLancaBridgeVars()
    }
}

task("deploy-lanca-bridge", "Deploy the Lanca Bridge")
    .addFlag("proxy", "Deploy the proxy")
    .addFlag("implementation", "Deploy the implementation")
    .addFlag("vars", "Set the contract variables")
    .setAction(async taskArgs => {
        try {
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
                liveChains = conceroChains.mainnet.infra
                await verifyContractVariables()
            } else {
                liveChains = conceroChains.testnet.infra
            }

            await deployLancaBridge({
                hre,
                deployableChains,
                liveChains,
                networkType,
                deployProxy: taskArgs.proxy,
                deployImplementation: taskArgs.implementation,
                setVars: taskArgs.vars,
            })
        } catch (error) {
            handleError(error, "deploy lanca bridge")
        }
    })

export default {}
