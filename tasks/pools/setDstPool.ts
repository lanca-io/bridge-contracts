import { CNetworkNames } from "../../types/CNetwork"
import { conceroNetworks } from "../../constants"
import { mainnetChains, testnetChains } from "../../constants/liveChains"
import { getFallbackClients } from "../../utils"
import { getEnvAddress } from "../../utils/getEnvVar"
import { ProxyEnum } from "../../constants/deploymentVariables"
import { Address } from "viem"
import log from "../../utils/log"

export async function setDstPools(poolChainName: CNetworkNames) {
    const isTestnet = conceroNetworks[poolChainName].type === "testnet"
    const dstPoolChains = isTestnet ? testnetChains : mainnetChains
    const cChain = conceroNetworks[poolChainName]
    const { publicClient, walletClient } = getFallbackClients(cChain)
    const { abi: poolAbi } = await import("../../artifacts/contracts/pools/LancaPoolCommon.sol/LancaPoolCommon.json")
    const [currentChainPoolAddress] = getEnvAddress(
        poolChainName === "baseSepolia" || poolChainName === "base"
            ? ProxyEnum.parentPoolProxy
            : ProxyEnum.childPoolProxy,
        poolChainName,
    )

    for (const dstPoolChain of dstPoolChains) {
        const dstChainPoolName = dstPoolChain.name
        if (poolChainName === dstChainPoolName) continue

        const [dstPoolProxy, dstPoolAlias] = getEnvAddress(
            dstChainPoolName === "base" || dstChainPoolName === "baseSepolia"
                ? ProxyEnum.parentPoolProxy
                : ProxyEnum.childPoolProxy,
            dstPoolChain.name,
        )

        const currentDstPool = (await publicClient.readContract({
            address: currentChainPoolAddress,
            abi: poolAbi,
            functionName: "getDstPoolByChainSelector",
            args: [dstPoolChain.chainSelector],
        })) as Address

        if (currentDstPool.toLowerCase() === dstPoolProxy.toLowerCase()) continue

        const { request: setDstPoolReq } = await publicClient.simulateContract({
            address: currentChainPoolAddress,
            abi: poolAbi,
            functionName: "setDstPool",
            args: [dstPoolChain.chainSelector, dstPoolProxy],
        })
        const setDstPoolHash = await walletClient.writeContract(setDstPoolReq)
        const { cumulativeGasUsed: setDstPoolGasUsed } = await publicClient.waitForTransactionReceipt({
            hash: setDstPoolHash,
        })
        const logMessage = `[Set] ${currentChainPoolAddress}.dstPool${dstPoolAlias}. Gas: ${setDstPoolGasUsed}`
        log(logMessage, "setDstPools", poolChainName)
    }
}
