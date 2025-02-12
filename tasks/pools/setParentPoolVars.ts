import { HardhatRuntimeEnvironment } from "hardhat/types"
import { CNetworkNames } from "../../types/CNetwork"
import { conceroNetworks } from "../../constants"
import { getFallbackClients } from "../../utils"
import { getEnvAddress } from "../../utils/getEnvVar"
import { parentPoolLiqCap, ProxyEnum } from "../../constants/deploymentVariables"
import log from "../../utils/log"
import { setDstPools } from "./setDstPool"

async function setParentPoolCap(poolChainName: CNetworkNames) {
    const cChain = conceroNetworks[poolChainName]
    const { publicClient, walletClient } = getFallbackClients(cChain)
    const { abi: poolAbi } = await import("../../artifacts/contracts/pools/LancaParentPool.sol/LancaParentPool.json")
    const [currentChainPoolAddress] = getEnvAddress(ProxyEnum.parentPoolProxy, poolChainName)

    const { request: setCapReq } = await publicClient.simulateContract({
        address: currentChainPoolAddress,
        abi: poolAbi,
        functionName: "setPoolCap",
        args: [parentPoolLiqCap],
    })
    const setCapHash = await walletClient.writeContract(setCapReq)
    const { cumulativeGasUsed: setCapGasUsed } = await publicClient.waitForTransactionReceipt({
        hash: setCapHash,
    })

    const logMessage = `[Set] ${currentChainPoolAddress}.cap -> ${parentPoolLiqCap}. Gas: ${setCapGasUsed}`
    log(logMessage, "setParentPoolCap", poolChainName)
}

export async function setParentPoolVars() {
    const hre: HardhatRuntimeEnvironment = require("hardhat")
    const poolChainName = hre.network.name as CNetworkNames

    await setDstPools(poolChainName)
    await setParentPoolCap(poolChainName)
}
