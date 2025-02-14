import { getEnvVar } from "../../utils"

type ArgBuilder = () => Promise<string[]>

export const getSimulationArgs: { [functionName: string]: ArgBuilder } = {
    pool_collect_liq: async () => {
        const liquidityRequestedFromEachPool = "0x147B0"
        const withdrawalId = "0x3e63da41d93846072a115187efd804333da52256b8ec17e9c05163d6903d561d"

        return ["0x0", "0x0", "0x0", "0x" + (84532).toString(16), liquidityRequestedFromEachPool, withdrawalId]
    },
    pool_get_child_pools_liquidity: async () => {
        const srcJsHashSum = "0xef64cf53063700bbbd8e42b0282d3d8579aac289ea03f826cf16f9bd96c7703a"
        const ethersHashSum = "0x984202f6c36a048a80e993557555488e5ae13ff86f2dfbcde698aacd0a7d4eb4"

        return [srcJsHashSum, ethersHashSum, "0x01", "0x" + (84532).toString(16)]
    },
    pool_redistribute_liq: async () => {
        const newPoolChainSelector = "0x" + BigInt(getEnvVar("CL_CCIP_CHAIN_SELECTOR_OPTIMISM")).toString(16)
        const distributeLiquidityRequestId = "0x05f8cc312ae3687e5581353da9c5889b92d232f7776c8b81dc234fb330fda265"
        const distributionType = "0x00"
        const chainId = "0x" + Number(8453).toString(16)

        return ["0x0", "0x0", "0x0", newPoolChainSelector, distributeLiquidityRequestId, distributionType, chainId]
    },
}
