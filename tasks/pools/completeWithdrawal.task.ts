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
import { Address } from "viem"

async function completeWithdrawal(isTestnet: boolean, lpAddress: Address) {
    const parentPoolChain = conceroChains[isTestnet ? "testnet" : "mainnet"].parentPool[0]
    if (!parentPoolChain) throw new Error("Parent pool chain not found")

    const { publicClient, walletClient } = getClients(parentPoolChain.viemChain)
    const [parentPoolAddress] = getEnvAddress(ProxyEnum.parentPoolProxy, parentPoolChain.name)
    const { abi: parentPoolAbi } = await import(
        "../../artifacts/contracts/pools/LancaParentPool.sol/LancaParentPool.json"
    )
    const { abi: parentPoolClfClaAbi } = await import(
        "../../artifacts/contracts/pools/LancaParentPoolCLFCLA.sol/LancaParentPoolCLFCLA.json"
    )

    const completeWithdrawalReq = (
        await publicClient.simulateContract({
            account: walletClient.account,
            abi: [...parentPoolAbi, ...parentPoolClfClaAbi],
            functionName: "completeWithdrawal",
            address: parentPoolAddress,
            args: [lpAddress],
        })
    ).request

    const completeWithdrawalHash = await walletClient.writeContract(completeWithdrawalReq)
    const completeWithdrawalStatus = (
        await publicClient.waitForTransactionReceipt({ ...viemReceiptConfig, hash: completeWithdrawalHash })
    ).status

    if (completeWithdrawalStatus === "reverted") {
        throw new Error(`Transaction reverted. Hash: ${completeWithdrawalHash}`)
    }

    console.log(`Transaction successful. Hash: ${completeWithdrawalHash}`)
}

task("complete-withdraw-from-pool", "Complete withdraw from the pool")
    .addParam("lpaddress")
    .setAction(async taskArgs => {
        try {
            const hre: HardhatRuntimeEnvironment = require("hardhat")
            compileContracts({ quiet: true })
            const name = hre.network.name as CNetworkNames
            const isTestnet = conceroNetworks[name].type === "testnet"

            await completeWithdrawal(isTestnet, taskArgs.lpaddress)
        } catch (error) {
            handleError(error, "complete-withdraw-from-pool")
        }
    })

export default {}
