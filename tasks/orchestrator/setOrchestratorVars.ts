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
import { arbitrum, avalanche, base, optimism, polygon } from "viem/chains"

async function setDstLancaOrchestratorContracts() {
    const hre: HardhatRuntimeEnvironment = require("hardhat")
    const cName = hre.network.name as CNetworkNames
    const cNetwork = conceroNetworks[cName]
    const { publicClient, walletClient } = getFallbackClients(cNetwork)
    const cChains = cNetwork.type === "mainnet" ? mainnetChains : testnetChains
    const { abi: lancaOrchestratorAbi } = await import(
        "../../artifacts/contracts/orchestrator/LancaOrchestrator.sol/LancaOrchestrator.json"
    )
    const lancaOrchestrator = getEnvVar(`LANCA_ORCHESTRATOR_PROXY_${networkEnvKeys[cName]}`) as Address

    for (const dstChain in cChains) {
        const dstLancaChainName = cChains[dstChain].name as CNetworkNames
        if (cName === dstLancaChainName) continue
        const dstLancaOrchestrator = getEnvVar(
            `LANCA_ORCHESTRATOR_PROXY_${networkEnvKeys[dstLancaChainName]}`,
        ) as Address
        const dstChainSelector = cChains[dstChain].chainSelector

        const currentDstOrchestrator = (await publicClient.readContract({
            address: lancaOrchestrator,
            abi: lancaOrchestratorAbi,
            functionName: "getLancaOrchestratorByChain",
            args: [dstChainSelector],
        })) as Address

        if (currentDstOrchestrator?.toLowerCase() === dstLancaOrchestrator.toLowerCase()) {
            const logMessage = `[Skip] ${cName}.dstLancaOrchestrator${dstLancaChainName}. Already set`
            log(logMessage, "dstDstLancaOrchestrator", cName)
            continue
        }

        const { request } = await publicClient.simulateContract({
            account: walletClient.account,
            address: lancaOrchestrator,
            abi: lancaOrchestratorAbi,
            functionName: "setDstLancaOrchestratorByChain",
            args: [dstChainSelector, dstLancaOrchestrator],
        })
        const txHash = await walletClient.writeContract(request)
        const setDstLancaOrchestratorContractsStatus = (
            await publicClient.waitForTransactionReceipt({ ...viemReceiptConfig, hash: txHash })
        ).status

        if (setDstLancaOrchestratorContractsStatus === "success") {
            log(
                `Set Lanca Orchestrator Contract: ${dstChain} -> ${dstLancaOrchestrator}. Hash: ${txHash}`,
                "setDstDstLancaOrchestrator",
                cName,
            )
        } else {
            throw new Error(
                `Failed to set Lanca Orchestrator Contract: ${dstChain} -> ${dstLancaOrchestrator}. Hash: ${txHash}`,
            )
        }
    }
}

const allowedRouters = {
    [arbitrum.id]: [getEnvVar("SUSHISWAP_ROUTER_ARBITRUM")],
    [base.id]: [getEnvVar("SUSHISWAP_ROUTER_BASE")],
    [optimism.id]: [getEnvVar("SUSHISWAP_ROUTER_OPTIMISM")],
    [polygon.id]: [getEnvVar("SUSHISWAP_ROUTER_POLYGON")],
    [avalanche.id]: [getEnvVar("SUSHISWAP_ROUTER_AVALANCHE")],
}

async function setAllowedDexRouters() {
    const hre: HardhatRuntimeEnvironment = require("hardhat")
    const cName = hre.network.name as CNetworkNames
    const cNetwork = conceroNetworks[cName]
    const { publicClient, walletClient } = getFallbackClients(cNetwork)
    const { abi: lancaOrchestratorAbi } = await import(
        "../../artifacts/contracts/orchestrator/LancaOrchestrator.sol/LancaOrchestrator.json"
    )
    const lancaOrchestrator = getEnvVar(`LANCA_ORCHESTRATOR_PROXY_${networkEnvKeys[cName]}`) as Address

    const allowedRoutersForChain = allowedRouters[cNetwork.chainId]
    if (!allowedRoutersForChain) {
        log(`No allowed routers for ${cName}`, "setAllowedDexRouters", cName)
        return
    }

    for (const router of allowedRoutersForChain) {
        const currentAllowedRouters = (await publicClient.readContract({
            address: lancaOrchestrator,
            abi: lancaOrchestratorAbi,
            functionName: "isDexRouterAllowed",
            args: [router],
        })) as boolean

        if (currentAllowedRouters) {
            const logMessage = `[Skip] ${cName}.allowedDexRouter.${router}. Already set`
            log(logMessage, "setDexRouterAddress", cName)
            continue
        }

        const { request } = await publicClient.simulateContract({
            account: walletClient.account,
            address: lancaOrchestrator,
            abi: lancaOrchestratorAbi,
            functionName: "setDexRouterAddress",
            args: [router, true],
        })
        const txHash = await walletClient.writeContract(request)
        const setAllowedDexRoutersStatus = (
            await publicClient.waitForTransactionReceipt({ ...viemReceiptConfig, hash: txHash })
        ).status

        if (setAllowedDexRoutersStatus === "success") {
            log(`Set Allowed Dex Router: ${router}. Hash: ${txHash}`, "setAllowedDexRouters", cName)
        } else {
            throw new Error(`Failed to set Allowed Dex Router: ${router}. Hash: ${txHash}`)
        }
    }
}

export async function setOrchestratorVars() {
    await setDstLancaOrchestratorContracts()
    await setAllowedDexRouters()
}
