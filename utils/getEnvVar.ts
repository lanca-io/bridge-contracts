import process from "process"
import { shorten } from "./formatting"
import { CNetworkNames } from "../types/CNetwork"
import { Address } from "viem"
import { EnvPrefixes } from "../types/deploymentVariables"
import { networkEnvKeys } from "../constants/conceroNetworks"
import { envPrefixes } from "../constants/deploymentVariables"

export function getEnvVar(key: string): string {
    const value = process.env[key]
    if (value === undefined) throw new Error(`Missing required environment variable ${key}`)
    if (value === "") throw new Error(`${key} must not be empty`)
    return value
}

export function getEnvAddress(prefix: keyof EnvPrefixes, networkName?: CNetworkNames | string): [Address, string] {
    const searchKey = networkName ? `${envPrefixes[prefix]}_${networkEnvKeys[networkName]}` : envPrefixes[prefix]
    const value = getEnvVar(searchKey) as Address
    const friendlyName = `${prefix}(${shorten(value)})`

    return [value, friendlyName]
}
