import { CNetworkNames } from "../../types/CNetwork"
import { conceroNetworks } from "../../constants"
import { mainnetChains, testnetChains } from "../../constants/liveChains"
import { getFallbackClients } from "../../utils"
import { getEnvAddress } from "../../utils/getEnvVar"
import { ProxyEnum } from "../../constants/deploymentVariables"
import { Address } from "viem"
import log from "../../utils/log"

export async function setDstPools(currentChainPoolName: CNetworkNames) {
    const isTestnet = conceroNetworks[currentChainPoolName].type === "testnet"
    const dstPoolChains = isTestnet ? testnetChains : mainnetChains
    const cChain = conceroNetworks[currentChainPoolName]
    const { publicClient, walletClient } = getFallbackClients(cChain)
    const { abi: poolAbi } = await import("../../artifacts/contracts/pools/LancaPoolCommon.sol/LancaPoolCommon.json")
    const isParentPool = currentChainPoolName === "baseSepolia" || currentChainPoolName === "base"
    const [currentChainPoolAddress] = getEnvAddress(
        isParentPool ? ProxyEnum.parentPoolProxy : ProxyEnum.childPoolProxy,
        currentChainPoolName,
    )

    for (const dstPoolChain of dstPoolChains) {
        const dstChainPoolName = dstPoolChain.name
        if (currentChainPoolName === dstChainPoolName) continue
        const isDstPoolParent = dstChainPoolName === "baseSepolia" || dstChainPoolName === "base"
        const [dstPoolProxy, dstPoolAlias] = getEnvAddress(
            isDstPoolParent ? ProxyEnum.parentPoolProxy : ProxyEnum.childPoolProxy,
            dstPoolChain.name,
        )
        const currentDstPool = (await publicClient.readContract({
            address: currentChainPoolAddress,
            abi: poolAbi,
            functionName: "getDstPoolByChainSelector",
            args: [dstPoolChain.chainSelector],
        })) as Address

        if (currentDstPool.toLowerCase() === dstPoolProxy.toLowerCase()) {
            const logMessage = `[Skip] ${currentChainPoolAddress}.dstPool${dstPoolAlias}. Already set`
            log(logMessage, "setDstPools", currentChainPoolName)
            continue
        }

        if (isParentPool) {
            const { abi: parentPoolAbi } = await import(
                "../../artifacts/contracts/pools/LancaParentPool.sol/LancaParentPool.json"
            )

            const { request: setDstPoolReq } = await publicClient.simulateContract({
                account: walletClient.account,
                address: currentChainPoolAddress,
                abi: parentPoolAbi,
                functionName: "setDstPool",
                args: [dstPoolChain.chainSelector, dstPoolProxy, false],
            })

            const setDstPoolHash = await walletClient.writeContract(setDstPoolReq)
            const { cumulativeGasUsed, status } = await publicClient.waitForTransactionReceipt({
                hash: setDstPoolHash,
            })

            if (status !== "success")
                throw new Error(`Failed to set dst pool ${dstPoolAlias} on ${currentChainPoolName}`)

            const logMessage = `[Set] ${currentChainPoolAddress}.dstPool${dstPoolAlias}. Gas: ${cumulativeGasUsed}`
            log(logMessage, "setDstPools", currentChainPoolName)
        } else {
            const { abi: childPoolAbi } = await import(
                "../../artifacts/contracts/pools/LancaChildPool.sol/LancaChildPool.json"
            )

            const { request: setDstPoolReq } = await publicClient.simulateContract({
                account: walletClient.account,
                address: currentChainPoolAddress,
                abi: childPoolAbi,
                functionName: "setDstPool",
                args: [dstPoolChain.chainSelector, dstPoolProxy],
            })
            const setDstPoolHash = await walletClient.writeContract(setDstPoolReq)
            const { cumulativeGasUsed, status } = await publicClient.waitForTransactionReceipt({
                hash: setDstPoolHash,
            })

            if (status !== "success")
                throw new Error(`Failed to set dst pool ${dstPoolAlias} on ${currentChainPoolName}`)

            const logMessage = `[Set] ${currentChainPoolAddress}.dstPool${dstPoolAlias}. Gas: ${cumulativeGasUsed}`
            log(logMessage, "setDstPools", currentChainPoolName)
        }
    }
}
