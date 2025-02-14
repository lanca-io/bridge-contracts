import { ProxyEnum } from "../constants/deploymentVariables"

export type IProxyType = keyof typeof ProxyEnum

type ProxyEnvPrefixes = {
    [key in ProxyEnum]: string
}
export type EnvPrefixes = ProxyEnvPrefixes & {
    parentPoolProxyAdmin: string
    lancaBridgeProxyAdmin: string
    lancaBridgeProxy: string
    orchestratorProxyAdmin: string
    orchestratorProxy: string
    orchestrator: string
    parentPool: string
    childPoolProxyAdmin: string
    childPool: string
    lancaBridge: string
    lpToken: string
    pause: string
    poolMessenger0: string
    poolMessenger1: string
    poolMessenger2: string
}

/**
 * Update an environment variable in the .env file
 * @param key The key of the environment variable to update
 * @param newValue The new value of the environment variable
 * @param envFileName The name of the .env file to update
 * usage: // updateEnvVariable("CLF_DON_SECRETS_VERSION_SEPOLIA", "1712841283", "../../../.env.clf");
 */
export type EnvFileName = "cla" | "clf" | "ccip" | "deployments.mainnet" | "deployments.testnet" | "apikeys" | "tokens"
