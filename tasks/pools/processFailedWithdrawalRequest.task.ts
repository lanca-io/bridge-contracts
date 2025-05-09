import { task } from "hardhat/config"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { compileContracts } from "../../utils/compileContracts"
import { conceroNetworks } from "../../constants"
import { CNetworkNames } from "../../types/CNetwork"
import { handleError } from "../../utils/handleError"
import { getEnvAddress } from "../../utils/getEnvVar"
import { getClients } from "../../utils/getViemClients"
import { Address } from "viem"

async function processFailedWithdrawalRequest(isTestnet: boolean, failedClfReqId: string) {
    const parentPoolAddress = getEnvAddress("PARENT_POOL_PROXY_" + isTestnet ? "BASE_SEPOLIA" : "BASE") as Address
    const { walletClient, publicClient } = getClients(
        isTestnet ? conceroNetworks.baseSepolia.viemChain : conceroNetworks.base.viemChain,
    )
    const { abi: parentPoolAbi } = await import(
        "../../artifacts/contracts/pools/LancaParentPool.sol/LancaParentPool.json"
    )

    const { request } = await publicClient.simulateContract({
        account: walletClient.account,
        abi: parentPoolAbi,
        address: parentPoolAddress,
        functionName: "processFailedWithdrawalRequest",
        args: [failedClfReqId],
    })
    const hash = await walletClient.writeContract(request)
    const { status } = await publicClient.waitForTransactionReceipt({ hash })

    console.log("withdrawal requests processed", status, hash)
}

const TASK_NAME = "process-failed-withdrawal-request"

task(TASK_NAME, "")
    .addParam("id")
    .setAction(async taskArgs => {
        try {
            const hre: HardhatRuntimeEnvironment = require("hardhat")
            compileContracts({ quiet: true })
            const name = hre.network.name as CNetworkNames
            const isTestnet = conceroNetworks[name].type === "testnet"

            await processFailedWithdrawalRequest(isTestnet, taskArgs.id)
        } catch (error) {
            handleError(error, TASK_NAME)
        }
    })

export default {}
