import { task } from "hardhat/config"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { getClients } from "../../utils/getViemClients"
import { conceroNetworks } from "../../constants"
import { getEnvVar } from "../../utils/getEnvVar"
import { networkEnvKeys } from "../../constants/conceroNetworks"
import { CNetworkNames } from "../../types/CNetwork"
import { isMasterChain } from "../../utils"
import { Address, formatUnits } from "viem"

task("get-loans-in-use", "").setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat")
    const name = hre.network.name as CNetworkNames
    const conceroChain = conceroNetworks[name]
    const viemChain = conceroNetworks[name].viemChain
    const { publicClient } = getClients(viemChain)
    const { abi: lancaPoolAbi } = await import(
        "../../artifacts/contracts/pools/LancaPoolCommon.sol/LancaPoolCommon.json"
    )

    const loansInUse = (await publicClient.readContract({
        address: getEnvVar(
            (isMasterChain(conceroChain) ? "PARENT_POOL_PROXY_" : "CHILD_POOL_PROXY_") + networkEnvKeys[name],
        ) as Address,
        abi: lancaPoolAbi,
        functionName: "getUsdcLoansInUse",
        args: [],
    })) as bigint

    console.table([formatUnits(loansInUse, 6)])
})

export default {}
