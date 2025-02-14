import { task } from "hardhat/config"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { compileContracts } from "../../utils/compileContracts"
import { conceroNetworks } from "../../constants"
import { CNetworkNames } from "../../types/CNetwork"
import { conceroChains } from "../../constants/liveChains"
import { getClients } from "../../utils/getViemClients"
import { getEnvAddress, getEnvVar } from "../../utils/getEnvVar"
import { ProxyEnum, viemReceiptConfig } from "../../constants/deploymentVariables"
import { decodeEventLog, parseUnits } from "viem"
import { sleep } from "@nomicfoundation/hardhat-verify/internal/utilities"
import { handleError } from "../../utils/handleError"
import { approve } from "../../utils/approve"
import { networkEnvKeys } from "../../constants/conceroNetworks"

async function depositToPoo(isTestnet: boolean) {
    const parentPoolChain = conceroChains[isTestnet ? "testnet" : "mainnet"].parentPool[0]
    if (!parentPoolChain) throw new Error("Parent pool chain not found")

    const { publicClient, walletClient } = getClients(parentPoolChain.viemChain)
    const [parentPoolAddress] = getEnvAddress(ProxyEnum.parentPoolProxy, parentPoolChain.name)
    const { abi: parentPoolAbi } = await import(
        "../../artifacts/contracts/pools/LancaParentPool.sol/LancaParentPool.json"
    )
    const depositAmountUsdc = parseUnits("20", 6)

    const startDepositReq = (
        await publicClient.simulateContract({
            account: walletClient.account,
            address: parentPoolAddress,
            abi: parentPoolAbi,
            functionName: "startDeposit",
            args: [depositAmountUsdc],
        })
    ).request
    const startDepositTxHash = await walletClient.writeContract(startDepositReq)
    const { status: startDepositTxStatus, logs: startDepositTxLogs } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash: startDepositTxHash,
    })
    if (startDepositTxStatus !== "success") throw new Error("Start deposit failed")

    console.log("Deposit initiated", startDepositTxHash)

    const depositId = startDepositTxLogs.find(log => {
        try {
            const decodedLog = decodeEventLog({ abi: parentPoolAbi, data: log.data, topics: log.topics })
            if (decodedLog.eventName === "DepositInitiated") return true
            return false
        } catch (e) {
            return false
        }
    }).topics[1]

    if (!depositId) throw new Error("Deposit initiated id not found")

    await sleep(20_000)

    await approve(
        getEnvVar(`USDC_${networkEnvKeys[parentPoolChain.name]}`),
        parentPoolAddress,
        depositAmountUsdc,
        walletClient,
        publicClient,
    )

    const completeDepositReq = (
        await publicClient.simulateContract({
            account: walletClient.account,
            address: parentPoolAddress,
            abi: parentPoolAbi,
            functionName: "completeDeposit",
            args: [depositId],
        })
    ).request

    const completeDepositTxHash = await walletClient.writeContract(completeDepositReq)
    const completeDepositTxStatus = (
        await publicClient.waitForTransactionReceipt({ ...viemReceiptConfig, hash: completeDepositTxHash })
    ).status

    if (completeDepositTxStatus !== "success") throw new Error("Complete deposit failed")

    console.log("Deposit successful", completeDepositTxHash)
}

task("deposit-to-pool", "Deposit to the pool").setAction(async taskArgs => {
    try {
        const hre: HardhatRuntimeEnvironment = require("hardhat")
        compileContracts({ quiet: true })
        const name = hre.network.name as CNetworkNames
        const isTestnet = conceroNetworks[name].type === "testnet"

        await depositToPoo(isTestnet)
    } catch (error) {
        handleError(error, "deposit-to-pool")
    }
})

export default {}
