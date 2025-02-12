type envString = string | undefined

export type CLFSecrets = {
    POOL_MESSENGER_0_PRIVATE_KEY: envString
    INFURA_API_KEY: envString
    ALCHEMY_API_KEY: envString
    PARENT_POOL_INFURA_API_KEY: envString
    PARENT_POOL_ALCHEMY_API_KEY: envString
}

export const clfSecrets: CLFSecrets = {
    POOL_MESSENGER_0_PRIVATE_KEY: process.env.POOL_MESSENGER_0_PRIVATE_KEY,
    INFURA_API_KEY: process.env.INFURA_API_KEY,
    ALCHEMY_API_KEY: process.env.ALCHEMY_API_KEY,
    PARENT_POOL_INFURA_API_KEY: process.env.PARENT_POOL_INFURA_API_KEY,
    PARENT_POOL_ALCHEMY_API_KEY: process.env.PARENT_POOL_ALCHEMY_API_KEY,
}

export const CLF_SECRETS_TESTNET_EXPIRATION = 4320
export const CLF_SECRETS_MAINNET_EXPIRATION = 129600
