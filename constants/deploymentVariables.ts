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
    lancaBridgeProxyAdmin: "LANCA_BRIDGE_PROXY_ADMIN",
    lancaBridgeProxy: "LANCA_BRIDGE_PROXY",
    lancaBridge: "LANCA_BRIDGE",
    orchestrator: "LANCA_ORCHESTRATOR",
    orchestratorProxy: "LANCA_ORCHESTRATOR_PROXY",
    orchestratorProxyAdmin: "LANCA_ORCHESTRATOR_PROXY_ADMIN",
    parentPoolProxy: "PARENT_POOL_PROXY",
    childPoolProxyAdmin: "CHILD_POOL_PROXY_ADMIN",
    childPoolProxy: "CHILD_POOL_PROXY",
    childPool: "CHILD_POOL",
    parentPool: "PARENT_POOL",
    lpToken: "LPTOKEN",
    pause: "CONCERO_PAUSE",
}

// @dev parent pool deploy vars
export const PARENT_POOL_LIQ_CAP = parseUnits("60000", 18)
export const PARENT_POOL_CLF_SECRETS_SLOT_ID = "1"
export const PARENT_POOL_TESTNET_WITHDRAWAL_COOLDOWN_SECONDS = 60
export const PARENT_POOL_MAINNET_WITHDRAWAL_COOLDOWN_SECONDS = 604_800

// @dev lanca bridge deploy vars
export const LANCA_BRIDGE_TESTNET_BATCHED_TX_THRESHOLD = parseUnits("7", 6)
export const LANCA_BRIDGE_MAINNET_BATCHED_TX_THRESHOLD = parseUnits("3000", 6)
