import type { WaitForTransactionReceiptParameters } from "viem/actions/public/waitForTransactionReceipt";
import { WriteContractParameters } from "viem";
import { EnvPrefixes } from "../types/deploymentVariables";

export const viemReceiptConfig: WaitForTransactionReceiptParameters = {
    timeout: 0,
    confirmations: 2,
};

export const writeContractConfig: WriteContractParameters = {
    gas: 3000000n, // 3M
};

export enum ProxyEnum {
    conceroRouterProxy = "conceroRouterProxy",
}

export const envPrefixes: EnvPrefixes = {
    conceroRouterProxy: "CONCERO_ROUTER_PROXY",
    conceroRouterProxyAdmin: "CONCERO_ROUTER_PROXY_ADMIN",
    create3Factory: "CREATE3_FACTORY",
    pause: "CONCERO_PAUSE",
};
