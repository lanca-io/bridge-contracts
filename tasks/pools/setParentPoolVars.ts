import { HardhatRuntimeEnvironment } from "hardhat/types"
import { CNetworkNames } from "../../types/CNetwork"
import { conceroNetworks } from "../../constants"
import { getFallbackClients } from "../../utils"
import { getEnvAddress } from "../../utils/getEnvVar"
import { PARENT_POOL_LIQ_CAP, ProxyEnum } from "../../constants/deploymentVariables"
import log from "../../utils/log"
import { setDstPools } from "./setDstPool"

async function setParentPoolCap(poolChainName: CNetworkNames) {
    const cChain = conceroNetworks[poolChainName]
    const { publicClient, walletClient } = getFallbackClients(cChain)
    const { abi: poolAbi } = await import("../../artifacts/contracts/pools/LancaParentPool.sol/LancaParentPool.json")
    const [currentChainPoolAddress] = getEnvAddress(ProxyEnum.parentPoolProxy, poolChainName)

    const currentPoolCup = await publicClient.readContract({
        address: currentChainPoolAddress,
        abi: poolAbi,
        functionName: "getLiquidityCap",
    })

    if (currentPoolCup === PARENT_POOL_LIQ_CAP) {
        const logMessage = `[Skip] ${currentChainPoolAddress}.setParentPoolCap. Already set`
        log(logMessage, "setParentPoolCap", poolChainName)
        return
    }

    const { request: setCapReq } = await publicClient.simulateContract({
        account: walletClient.account,
        address: currentChainPoolAddress,
        abi: poolAbi,
        functionName: "setPoolCap",
        args: [PARENT_POOL_LIQ_CAP],
    })
    const setCapHash = await walletClient.writeContract(setCapReq)
    const { cumulativeGasUsed: setCapGasUsed } = await publicClient.waitForTransactionReceipt({
        hash: setCapHash,
    })

    const logMessage = `${currentChainPoolAddress}.cap -> ${PARENT_POOL_LIQ_CAP}. Gas: ${setCapGasUsed}`
    log(logMessage, "setParentPoolCap", poolChainName)
}

export async function setParentPoolVars() {
    const hre: HardhatRuntimeEnvironment = require("hardhat")
    const poolChainName = hre.network.name as CNetworkNames

    await setDstPools(poolChainName)
    await setParentPoolCap(poolChainName)
}
