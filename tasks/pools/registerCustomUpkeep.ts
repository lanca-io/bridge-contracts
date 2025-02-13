import { CNetworkNames } from "../../types/CNetwork"
import { Address, erc20Abi, Hex } from "viem"
import log, { err } from "../../utils/log"
import { conceroNetworks } from "../../constants"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { updateEnvAddress } from "../../utils/updateEnvVariable"
import { EnvFileName } from "../../types/deploymentVariables"
import { getEnvAddress } from "../../utils/getEnvVar"
import { getFallbackClients } from "../../utils"
import { RegistrationParamsAbi as RegistrationParamsAbiFunc } from "../../abi/AutomationRegistryInterfaceAbi"
import { Hash } from "viem"


// @dev 0 is Conditional upkeep, 1 is Log trigger upkeep
export type TriggerType = 0 | 1

export interface RegistrationParams {
    upkeepContract: Address
    amount: bigint
    adminAddress: Address
    gasLimit: number
    triggerType: TriggerType
    billingToken: Address
    name: string
    encryptedEmail: Hex
    checkData: Hex
    // @dev 0x for conditional upkeeps
    triggerConfig: Hex
    offchainConfig: Hex
}

export interface UpkeepInfo {
    registryAddress: Address
    upkeepId: string
    registrationHash: Hash
    name: string
    target: Address
    performGas: string
    balance: string
    checkData: Hex
    admin: Address
    maxValidBlockNumber: string
    lastPerformBlockNumber: string
    status: string
    amountSpent: string
    offchainConfig: Hex
    minBalance: string
    registrarAddress: Address
    forwarderAddress: Address
    proposedAdmin: Address | null
    triggerType: string
    triggerConfig: string
    network: string
    createdAt: string
    billingToken: Address
}

export async function registerCustomUpkeep(hre: HardhatRuntimeEnvironment, args: RegistrationParams) {
    const { deployer } = await hre.getNamedAccounts()
    const cName = hre.network.name as CNetworkNames
    const cNetwork = conceroNetworks[cName]
    const { publicClient, walletClient } = getFallbackClients(cNetwork)
    const { linkToken, type } = cNetwork

    const [keepersRegistrarAddress] = getEnvAddress("automationRegistrar", cName)

    const linkTokenAddress = linkToken as Address

    log(`🔗 Keepers Registrar Address: ${keepersRegistrarAddress}`, "registerCustomUpkeep", cName)
    log(`🔗 LINK Token Address: ${linkTokenAddress}`, "registerCustomUpkeep", cName)

    const { upkeepContract } = args

    log(`🔗 Using Upkeep Contract: ${upkeepContract}`, "registerCustomUpkeep", cName)
    log("🛠  Registering Upkeep...", "registerCustomUpkeep", cName)

    args.adminAddress = deployer.toLowerCase() as Address

    try {
        log(`🔗 Approving LINK tokens for Registrar...`, "registerCustomUpkeep", cName)

        const { request: approveRequest } = await publicClient.simulateContract({
            account: walletClient.account,
            functionName: "approve",
            args: [keepersRegistrarAddress, args.amount],
            abi: erc20Abi,
            address: linkTokenAddress,
        })

        const approveTxHash = await walletClient.writeContract(approveRequest)

        log(`✅ Tokens approved! TxHash: ${approveTxHash}`, "registerCustomUpkeep", cName)

        const { request } = await publicClient.simulateContract({
            account: walletClient.account,
            functionName: "registerUpkeep",
            args: [args],
            abi: RegistrationParamsAbiFunc,
            address: keepersRegistrarAddress.toLocaleLowerCase() as Address,
        })

        const upkeepId = BigInt(await walletClient.writeContract(request)).toString()

        log(`✅ Upkeep registered! Upkeep ID: ${upkeepId}`, "registerCustomUpkeep", cName)
        log(`🔍 Fetching automationForwarder for Upkeep ID: ${upkeepId}...`, "registerCustomUpkeep", cName)

        const { forwarderAddress } = await getUpkeepInfo(upkeepId, cName)

        log(`✅ Found automationForwarder: ${forwarderAddress}`, "registerCustomUpkeep", cName)

        const envFileName = `deployments.${type}` as EnvFileName

        log(`🔄 Updating automationForwarder in ${envFileName}...`, "registerCustomUpkeep", cName)
        updateEnvAddress("automationForwarder", cName, forwarderAddress, envFileName)

        log(`✅ automationForwarder updated in .env.${envFileName}!`, "registerCustomUpkeep", cName)
    } catch (error) {
        err(`❌ Error registering upkeep: ${error.message}`, "registerCustomUpkeep", cName)
        throw error
    }
}

async function getUpkeepInfo(id: string, network: CNetworkNames): Promise<UpkeepInfo> {
    const chainlinkNetworks: Record<CNetworkNames, string> = {
        baseSepolia: "ethereum-testnet-sepolia-base-1",
        avalancheFuji: "avalanche-testnet-fuji",
        arbitrumSepolia: "ethereum-testnet-sepolia-arbitrum-1",
        optimismSepolia: "ethereum-testnet-sepolia-optimism-1",
        polygonAmoy: "polygon-testnet-amoy",
        sepolia: "ethereum-testnet-sepolia",
        localhost: "",

        avalanche: "avalanche-mainnet",
        arbitrum: "ethereum-mainnet-arbitrum-1",
        base: "ethereum-mainnet-base-1",
        optimism: "ethereum-mainnet-optimism-1",
        ethereum: "ethereum-mainnet",
        polygon: "polygon-mainnet",
        polygonZkEvm: "",
    }
    const chainLinkNetwork = chainlinkNetworks[network]

    const url = `https://automation.chain.link/api/query?query=AUTOMATION_UPKEEP_DETAILS_QUERY&variables={"network":"${chainLinkNetwork}","id":"${id}"}`
    const data = await fetch(url)
    const json = await data.json()
    return json.data.allAutomationUpkeeps.nodes[0]
}
