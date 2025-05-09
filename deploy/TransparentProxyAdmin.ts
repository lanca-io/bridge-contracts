import { Deployment } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import conceroNetworks from "../constants/conceroNetworks"
import { getEnvVar } from "../utils"
import log from "../utils/log"
import { IProxyType } from "../types/deploymentVariables"
import { getGasParameters } from "../utils/getGasPrice"
import { updateEnvAddress } from "../utils/updateEnvVariable"
import { CNetworkNames } from "../types/CNetwork"

const deployProxyAdmin: (hre: HardhatRuntimeEnvironment, proxyType: IProxyType) => Promise<void> = async function (
    hre: HardhatRuntimeEnvironment,
    proxyType: IProxyType,
) {
    const { proxyDeployer } = await hre.getNamedAccounts()
    const { deploy } = hre.deployments
    const { live } = hre.network
    const name = hre.network.name as CNetworkNames
    const networkType = conceroNetworks[name].type
    const initialOwner = getEnvVar(`PROXY_DEPLOYER_ADDRESS`)
    const { maxFeePerGas, maxPriorityFeePerGas } = await getGasParameters(conceroNetworks[name])

    log("Deploying...", `deployProxyAdmin: ${proxyType}`, name)
    const deployProxyAdmin = (await deploy("TransparentProxyAdmin", {
        from: proxyDeployer,
        args: [initialOwner],
        log: true,
        autoMine: true,
        // maxFeePerGas: maxFeePerGas.toString(),
        // maxPriorityFeePerGas: maxPriorityFeePerGas.toString(),
        gasLimit: 2_000_000,
    })) as Deployment

    if (live) {
        log(`Deployed at: ${deployProxyAdmin.address}`, `deployProxyAdmin: ${proxyType}`, name)
        updateEnvAddress(`${proxyType}Admin`, name, deployProxyAdmin.address, `deployments.${networkType}`)
    }
}

export default deployProxyAdmin
deployProxyAdmin.tags = ["TransparentProxyAdmin"]
