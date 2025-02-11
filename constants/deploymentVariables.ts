import type { WaitForTransactionReceiptParameters } from "viem/actions/public/waitForTransactionReceipt"
import { parseUnits, WriteContractParameters } from "viem"
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
    lancaBridge = "lancaBridge",
    parentPool = "parentPool",
    childPool = "childPool",
    orchestrator = "orchestrator",
}

export const envPrefixes: EnvPrefixes = {
    parentPoolProxyAdmin: "PARENT_POOL_PROXY_ADMIN",
    lancaBridge: "LANCA_BRIDGE",
    parentPool: "PARENT_POOL",
    childPoolProxyAdmin: "CHILD_POOL_PROXY_ADMIN",
    childPool: "CHILD_POOL",
    create3Factory: "CREATE3_FACTORY",
    pause: "CONCERO_PAUSE",
}

export const parentPoolLiqCap = parseUnits("60000", 18)
