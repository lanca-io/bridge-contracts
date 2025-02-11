import type { WaitForTransactionReceiptParameters } from "viem/actions/public/waitForTransactionReceipt"
import { WriteContractParameters } from "viem"
import { EnvPrefixes } from "../types/deploymentVariables"
import { getEnvVar } from "../utils"

export const poolMessengers: string[] = [
    getEnvVar("POOL_MESSENGER_0_ADDRESS"),
    getEnvVar("POOL_MESSENGER_0_ADDRESS"),
    getEnvVar("POOL_MESSENGER_0_ADDRESS"),
]

export const viemReceiptConfig: WaitForTransactionReceiptParameters = {
    timeout: 0,
    confirmations: 2,
}

export const writeContractConfig: WriteContractParameters = {
    gas: 3000000n, // 3M
}

export enum ProxyEnum {
    conceroRouterProxy = "conceroRouterProxy",
}

export const envPrefixes: EnvPrefixes = {
    conceroRouterProxy: "CONCERO_ROUTER_PROXY",
    conceroRouterProxyAdmin: "CONCERO_ROUTER_PROXY_ADMIN",
    create3Factory: "CREATE3_FACTORY",
    pause: "CONCERO_PAUSE",
}
