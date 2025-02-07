import { getFallbackClients } from "../../utils/getViemClients"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { conceroNetworks } from "../../constants"
import { CNetworkNames } from "../../types/CNetwork"
import { mainnetChains, testnetChains } from "../../constants/liveChains"
import { getEnvVar } from "../../utils"
import { networkEnvKeys } from "../../constants/conceroNetworks"
import { Address } from "viem"
import log from "../../utils/log"

async function setDstLancaBridgeContracts() {
    const hre: HardhatRuntimeEnvironment = require("hardhat")
    const cName = hre.network.name as CNetworkNames
    const cNetwork = conceroNetworks[cName]
    const { publicClient, walletClient } = getFallbackClients(cNetwork)
    const cChains = cNetwork.type === "mainnet" ? mainnetChains : testnetChains
    const { abi: lancaBridgeAbi } = await import("../../artifacts/contracts/bridge/LancaBridge.sol/LancaBridge.json")

    for (const dstChain in cChains) {
        const lancaBridge = getEnvVar(`LANCA_BRIDGE_PROXY${networkEnvKeys[cName]}`) as Address
        const dstLancaBridge = getEnvVar(`LANCA_BRIDGE_PROXY${networkEnvKeys[dstChain]}`) as Address
        const dstChainSelector = cChains[dstChain].chainSelector

        try {
            const currentDstLancaBridgeAddress = (await publicClient.readContract({
                address: lancaBridge,
                abi: lancaBridgeAbi,
                functionName: "getLancaBridgeContractByChain",
                args: [dstChainSelector],
            })) as Address

            if (currentDstLancaBridgeAddress?.toLowerCase() === dstLancaBridge.toLowerCase()) continue
        } catch (e) {
            log(
                `Error getting current dst lanca bridge address: ${e?.shortMessage}`,
                "getLancaBridgeContractByChain",
                cName,
            )
        }

        const { request } = await publicClient.simulateContract({
            address: lancaBridge,
            abi: lancaBridgeAbi,
            functionName: "setLancaBridgeContract",
            args: [dstChainSelector, dstLancaBridge],
        })
        const txHash = await walletClient.writeContract(request)

        log(
            `Set Lanca Bridge Contract: ${dstChain} -> ${dstLancaBridge}. Hash: ${txHash}`,
            "setLancaBridgeContract",
            cName,
        )
    }
}

export async function setLancaBridgeVars() {
    await setDstLancaBridgeContracts()
}
