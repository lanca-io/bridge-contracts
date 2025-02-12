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
    lancaBridgeProxy = "lancaBridgeProxy",
    parentPoolProxy = "parentPoolProxy",
    childPoolProxy = "childPoolProxy",
    orchestratorProxy = "orchestratorProxy",
}

export const envPrefixes: EnvPrefixes = {
    parentPoolProxyAdmin: "PARENT_POOL_PROXY_ADMIN",
    lancaBridgeProxy: "LANCA_BRIDGE",
    parentPoolProxy: "PARENT_POOL_PROXY",
    childPoolProxyAdmin: "CHILD_POOL_PROXY_ADMIN",
    childPoolProxy: "CHILD_POOL_PROXY",
    childPool: "CHILD_POOL",
    parentPool: "PARENT_POOL",
    lpToken: "LPTOKEN",
    orchestratorProxy: "ORCHESTRATOR_PROXY",
    orchestrator: "ORCHESTRATOR",
    pause: "CONCERO_PAUSE",
}

export const parentPoolLiqCap = parseUnits("60000", 18)
export const parentPoolClfSecretsSlotId = "1"
export const PARENT_POOL_TESTNET_WITHDRAWAL_COOLDOWN_SECONDS = 60
export const PARENT_POOL_MAINNET_WITHDRAWAL_COOLDOWN_SECONDS = 604_800
