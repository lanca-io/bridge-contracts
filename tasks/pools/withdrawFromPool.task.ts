import { task } from "hardhat/config"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { compileContracts } from "../../utils/compileContracts"
import { conceroNetworks } from "../../constants"
import { CNetworkNames } from "../../types/CNetwork"
import { conceroChains } from "../../constants/liveChains"
import { getClients } from "../../utils/getViemClients"
import { getEnvAddress, getEnvVar } from "../../utils/getEnvVar"
import { ProxyEnum, viemReceiptConfig } from "../../constants/deploymentVariables"
import { handleError } from "../../utils/handleError"
import { approve } from "../../utils/approve"
import { networkEnvKeys } from "../../constants/conceroNetworks"
import { Address, erc20Abi, formatUnits } from "viem"

async function withdrawFromPool(isTestnet: boolean) {
    const parentPoolChain = conceroChains[isTestnet ? "testnet" : "mainnet"].parentPool[0]
    if (!parentPoolChain) throw new Error("Parent pool chain not found")

    const { publicClient, walletClient } = getClients(parentPoolChain.viemChain)
    const [parentPoolAddress] = getEnvAddress(ProxyEnum.parentPoolProxy, parentPoolChain.name)
    const { abi: parentPoolAbi } = await import(
        "../../artifacts/contracts/pools/LancaParentPool.sol/LancaParentPool.json"
    )
    const lpToken = getEnvVar(`LPTOKEN_${networkEnvKeys[parentPoolChain.name]}`) as Address
    const withdrawalAmount = await publicClient.readContract({
        address: lpToken,
        abi: erc20Abi,
        functionName: "balanceOf",
        args: [walletClient.account?.address],
    })

    console.log("withdrawalAmount", formatUnits(withdrawalAmount, 18))

    await approve(lpToken, parentPoolAddress, withdrawalAmount, walletClient, publicClient)

    const startWithdrawalReq = (
        await publicClient.simulateContract({
            account: walletClient.account,
            address: parentPoolAddress,
            abi: parentPoolAbi,
            functionName: "startWithdrawal",
            args: [withdrawalAmount],
        })
    ).request

    const startWithdrawalHash = await walletClient.writeContract(startWithdrawalReq)
    const startWithdrawalTxStatus = (
        await publicClient.waitForTransactionReceipt({
            ...viemReceiptConfig,
            hash: startWithdrawalHash,
        })
    ).status

    if (startWithdrawalTxStatus !== "success") throw new Error("Start withdrawal failed")

    console.log("Withdrawal initiated", startWithdrawalHash)
}

task("withdraw-from-pool", "Withdraw from the pool").setAction(async taskArgs => {
    try {
        const hre: HardhatRuntimeEnvironment = require("hardhat")
        compileContracts({ quiet: true })
        const name = hre.network.name as CNetworkNames
        const isTestnet = conceroNetworks[name].type === "testnet"

        await withdrawFromPool(isTestnet)
    } catch (error) {
        handleError(error, "deposit-to-pool")
    }
})

export default {}
