import { HardhatRuntimeEnvironment } from "hardhat/types"
import { handleError } from "../../utils/handleError"
import { getClients } from "../../utils/getViemClients"
import { conceroNetworks } from "../../constants"
import { getEnvVar } from "../../utils"
import { networkEnvKeys } from "../../constants/conceroNetworks"
import { Address } from "viem"
import { task } from "hardhat/config"

task("fix-clashed-withdrawals", "").setAction(async taskArgs => {
    try {
        const hre: HardhatRuntimeEnvironment = require("hardhat")
        const { publicClient, walletClient } = getClients(conceroNetworks[hre.network.name].viemChain)
        const parentPoolAddress = getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[hre.network.name]}`) as Address
        const { abi: parentPoolAbi } = await import(
            "../../artifacts/contracts/pools/LancaParentPool.sol/LancaParentPool.json"
        )

        const fixClashedWithdrawalsRequest = (
            await publicClient.simulateContract({
                account: walletClient.account,
                address: parentPoolAddress,
                abi: parentPoolAbi,
                functionName: "fixWithdrawRequestsStorage",
                args: [],
            })
        ).request
        const fixClashedWithdrawalsHash = await walletClient.writeContract(fixClashedWithdrawalsRequest)
        const fixClashedWithdrawalsStatus = (
            await publicClient.waitForTransactionReceipt({ hash: fixClashedWithdrawalsHash })
        ).status

        if (fixClashedWithdrawalsStatus !== "success") {
            throw new Error("tx failed" + fixClashedWithdrawalsHash)
        } else {
            console.log("tx success" + fixClashedWithdrawalsHash)
        }
    } catch (error) {
        handleError(error, "fix clashed withdrawals")
    }
})

export default {}
