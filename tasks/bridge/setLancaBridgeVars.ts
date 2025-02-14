import { getFallbackClients } from "../../utils/getViemClients"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { conceroNetworks } from "../../constants"
import { CNetworkNames } from "../../types/CNetwork"
import { mainnetChains, testnetChains } from "../../constants/liveChains"
import { getEnvVar } from "../../utils"
import { networkEnvKeys } from "../../constants/conceroNetworks"
import { Address } from "viem"
import log from "../../utils/log"
import { viemReceiptConfig } from "../../constants/deploymentVariables"

async function setDstLancaBridgeContracts() {
    const hre: HardhatRuntimeEnvironment = require("hardhat")
    const cName = hre.network.name as CNetworkNames
    const cNetwork = conceroNetworks[cName]
    const { publicClient, walletClient } = getFallbackClients(cNetwork)
    const cChains = cNetwork.type === "mainnet" ? mainnetChains : testnetChains
    const { abi: lancaBridgeAbi } = await import("../../artifacts/contracts/bridge/LancaBridge.sol/LancaBridge.json")

    for (const dstChain in cChains) {
        const lancaBridge = getEnvVar(`LANCA_BRIDGE_PROXY_${networkEnvKeys[cName]}`) as Address
        const dstLancaChainName = cChains[dstChain].name as CNetworkNames
        if (cName === dstLancaChainName) continue
        const dstLancaBridge = getEnvVar(`LANCA_BRIDGE_PROXY_${networkEnvKeys[dstLancaChainName]}`) as Address
        const dstChainSelector = cChains[dstChain].chainSelector

        const currentDstLancaBridgeAddress = (await publicClient.readContract({
            address: lancaBridge,
            abi: lancaBridgeAbi,
            functionName: "getLancaBridgeContractByChain",
            args: [dstChainSelector],
        })) as Address

        if (currentDstLancaBridgeAddress?.toLowerCase() === dstLancaBridge.toLowerCase()) {
            const logMessage = `[Skip] ${cName}.dstLancaBridge${dstLancaChainName}. Already set`
            log(logMessage, "dstDstLancaBridge", cName)
            continue
        }

        const { request } = await publicClient.simulateContract({
            account: walletClient.account,
            address: lancaBridge,
            abi: lancaBridgeAbi,
            functionName: "setLancaBridgeContract",
            args: [dstChainSelector, dstLancaBridge],
        })
        const txHash = await walletClient.writeContract(request)
        const setDstLancaBridgeContractsStatus = (
            await publicClient.waitForTransactionReceipt({
                ...viemReceiptConfig,
                hash: txHash,
            })
        ).status

        if (setDstLancaBridgeContractsStatus === "success") {
            log(
                `Set Lanca Bridge Contract: ${dstChain} -> ${dstLancaBridge}. Hash: ${txHash}`,
                "setLancaBridgeContract",
                cName,
            )
        } else {
            throw new Error(`Failed to set Lanca Bridge Contract: ${dstChain} -> ${dstLancaBridge}. Hash: ${txHash}`)
        }
    }
}

export async function setLancaBridgeVars() {
    await setDstLancaBridgeContracts()
}
