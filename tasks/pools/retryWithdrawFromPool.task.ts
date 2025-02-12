import { task } from "hardhat/config"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { compileContracts } from "../../utils/compileContracts"
import { conceroNetworks } from "../../constants"
import { CNetworkNames } from "../../types/CNetwork"
import { conceroChains } from "../../constants/liveChains"
import { getClients } from "../../utils/getViemClients"
import { getEnvAddress } from "../../utils/getEnvVar"
import { ProxyEnum, viemReceiptConfig } from "../../constants/deploymentVariables"
import { handleError } from "../../utils/handleError"

async function retryWithdrawFromPool(isTestnet: boolean) {
    const parentPoolChain = conceroChains[isTestnet ? "testnet" : "mainnet"].parentPool[0]
    if (!parentPoolChain) throw new Error("Parent pool chain not found")

    const { publicClient, walletClient } = getClients(parentPoolChain.viemChain)
    const [parentPoolAddress] = getEnvAddress(ProxyEnum.parentPoolProxy, parentPoolChain.name)
    const { abi: parentPoolAbi } = await import(
        "../../artifacts/contracts/pools/LancaParentPool.sol/LancaParentPool.json"
    )

    const retryWithdrawalReq = (
        await publicClient.simulateContract({
            account: walletClient.account,
            abi: parentPoolAbi,
            functionName: "retryPerformWithdrawalRequest",
            address: parentPoolAddress,
            args: [],
        })
    ).request

    const retryWithdrawalHash = await walletClient.writeContract(retryWithdrawalReq)
    const retryWithdrawalStatus = (
        await publicClient.waitForTransactionReceipt({ ...viemReceiptConfig, hash: retryWithdrawalHash })
    ).status

    if (retryWithdrawalStatus === "reverted") {
        throw new Error(`Transaction reverted. Hash: ${retryWithdrawalHash}`)
    }

    console.log(`Transaction successful. Hash: ${retryWithdrawalHash}`)
}

task("retry-withdraw-from-pool", "Retry withdraw from the pool").setAction(async taskArgs => {
    try {
        const hre: HardhatRuntimeEnvironment = require("hardhat")
        compileContracts({ quiet: true })
        const name = hre.network.name as CNetworkNames
        const isTestnet = conceroNetworks[name].type === "testnet"

        await retryWithdrawFromPool(isTestnet)
    } catch (error) {
        handleError(error, "retry-withdraw-from-pool")
    }
})

export default {}
