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
import { upgradeProxyImplementation } from "../transparentProxy/upgradeProxyImplementation.task"
import deployProxyAdmin from "../../deploy/TransparentProxyAdmin"
import { handleError } from "../../utils/handleError"
import deployLancaOrchestratorImplementation from "../../deploy/LancaOrchestrator"
import { setOrchestratorVars } from "./setOrchestratorVars"
import deployDexSwap from "../../deploy/DexSwap"

interface DeployOrchestratorParams {
    hre: HardhatRuntimeEnvironment
    liveChains: CNetwork[]
    deployableChains: CNetwork[]
    networkType: NetworkType
    deployProxy: boolean
    deployImplementation: boolean
    setVars: boolean
}

async function deployOrchestrator(params: DeployOrchestratorParams) {
    const { hre, deployProxy, deployImplementation, setVars } = params

    if (deployProxy) {
        await deployProxyAdmin(hre, ProxyEnum.orchestratorProxy)
        await deployTransparentProxy(hre, ProxyEnum.orchestratorProxy)
    }

    if (deployImplementation) {
        await deployDexSwap(hre)
        await deployLancaOrchestratorImplementation(hre)
        await upgradeProxyImplementation(hre, ProxyEnum.orchestratorProxy, false)
    }

    if (setVars) {
        await setOrchestratorVars()
    }
}

task("deploy-orchestrator", "Deploy the Orchestrator")
    .addFlag("proxy", "Deploy the proxy")
    .addFlag("implementation", "Deploy the implementation")
    .addFlag("vars", "Set the contract variables")
    .setAction(async taskArgs => {
        try {
            compileContracts({ quiet: true })
            const hre: HardhatRuntimeEnvironment = require("hardhat")

            const { live } = hre.network
            const name = hre.network.name as CNetworkNames
            const networkType = conceroNetworks[name].type
            let deployableChains: CNetwork[] = []
            if (live) deployableChains = [conceroNetworks[name]]

            let liveChains: CNetwork[] = []
            if (networkType === networkTypes.mainnet) {
                liveChains = conceroChains.mainnet.infra
                await verifyContractVariables()
            } else {
                liveChains = conceroChains.testnet.infra
            }

            await deployOrchestrator({
                hre,
                deployableChains,
                liveChains,
                networkType,
                deployProxy: taskArgs.proxy,
                deployImplementation: taskArgs.implementation,
                setVars: taskArgs.vars,
            })
        } catch (error) {
            handleError(error, "deploy orchestrator")
        }
    })

export default {}
