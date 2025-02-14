import { getEnvAddress } from "../../utils/getEnvVar"
import conceroNetworks from "../../constants/conceroNetworks"
import { privateKeyToAccount } from "viem/accounts"
import log, { err } from "../../utils/log"
import { task } from "hardhat/config"
import { ProxyEnum, viemReceiptConfig, writeContractConfig } from "../../constants/deploymentVariables"
import { formatGas } from "../../utils/formatting"
import { getFallbackClients } from "../../utils"
import { CNetworkNames } from "../../types/CNetwork"
import { EnvPrefixes } from "../../types/deploymentVariables"

export async function upgradeProxyImplementation(hre: any, proxyType: ProxyEnum, shouldPause: boolean) {
    const chainName = hre.network.name as CNetworkNames
    const { viemChain } = conceroNetworks[chainName]

    let implementationKey: keyof EnvPrefixes

    if (shouldPause) {
        implementationKey = "pause"
    } else if (proxyType === ProxyEnum.lancaBridgeProxy) {
        implementationKey = "lancaBridge"
    } else if (proxyType === ProxyEnum.parentPoolProxy) {
        implementationKey = "parentPool"
    } else if (proxyType === ProxyEnum.childPoolProxy) {
        implementationKey = "childPool"
    } else if (proxyType === ProxyEnum.orchestratorProxy) {
        implementationKey = "orchestrator"
    } else {
        err(`Proxy type ${proxyType} not found`, "upgradeProxyImplementation", chainName)
        return
    }

    const { abi: proxyAdminAbi } = await import(
        "../../artifacts/contracts/proxy/TransparentProxyAdmin.sol/TransparentProxyAdmin.json"
    )

    const viemAccount = privateKeyToAccount(`0x${process.env.PROXY_DEPLOYER_PRIVATE_KEY}`)
    const { walletClient, publicClient } = getFallbackClients(conceroNetworks[chainName], viemAccount)

    const [conceroProxy, conceroProxyAlias] = getEnvAddress(proxyType, chainName)
    const [proxyAdmin, proxyAdminAlias] = getEnvAddress(`${proxyType}Admin`, chainName)
    const [newImplementation, newImplementationAlias] = getEnvAddress(implementationKey, chainName)
    const [pauseDummy, pauseAlias] = getEnvAddress("pause", chainName)

    const implementation = shouldPause ? pauseDummy : newImplementation
    const implementationAlias = shouldPause ? pauseAlias : newImplementationAlias

    const { request } = await publicClient.simulateContract({
        address: proxyAdmin,
        abi: proxyAdminAbi,
        functionName: "upgradeAndCall",
        account: viemAccount,
        args: [conceroProxy, implementation, "0x"],
        chain: viemChain,
        ...writeContractConfig,
    })

    const txHash = await walletClient.writeContract(request)

    const { cumulativeGasUsed, status } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash: txHash,
    })

    if (status !== "success") {
        err(
            `Upgrade failed: ${conceroProxyAlias}.implementation -> ${implementationAlias}`,
            "upgradeProxyImplementation",
            chainName,
        )
        return
    }

    log(
        `Upgraded via ${proxyAdminAlias}: ${conceroProxyAlias}.implementation -> ${implementationAlias}. Gas : ${formatGas(cumulativeGasUsed)}, hash: ${txHash}`,
        `setProxyImplementation : ${proxyType}`,
        chainName,
    )
}

task("upgrade-proxy-implementation", "Upgrades the proxy implementation")
    .addFlag("pause", "Pause the proxy before upgrading", false)
    .addParam("proxytype", "The type of the proxy to upgrade", undefined)
    .setAction(async taskArgs => {
        await upgradeProxyImplementation(hre, taskArgs.proxytype, taskArgs.pause)
    })

export default {}
