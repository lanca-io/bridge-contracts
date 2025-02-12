import { CNetworkNames } from "../../types/CNetwork"
import { getEnvVar } from "../../utils"
import { Address, Hex } from "viem"
import log, { err } from "../../utils/log"
import { conceroNetworks } from "../../constants"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { BigNumber } from "ethers-v5"
import updateEnvVariable from "../../utils/updateEnvVariable"
import { EnvFileName } from "../../types/deploymentVariables"

export interface UpkeepRegisterArgs {
    linkTokenAddress: Address
    depositAmount: bigint | BigNumber
    upkeepName: string
    upkeepContractAddress: Address
    email: string
    // @dev 0x by default
    ocrConfig: Hex
    // @dev (0 = MANUAL)
    source: number
    data: string
}

export async function registerCustomUpkeep(
    hre: HardhatRuntimeEnvironment,
    args: UpkeepRegisterArgs,
    gasLimit: number = 500000,
) {
    const [deployer] = await hre.ethers.getSigners()
    const chainName = hre.network.name as CNetworkNames
    const { linkToken, type } = conceroNetworks[chainName]

    const keepersRegistrarAddress = getEnvVar(`AUTOMATION_REGISTRY_${chainName}`) as Address
    const linkTokenAddress = linkToken as Address

    log(`🔗 Keepers Registrar Address: ${keepersRegistrarAddress}`, "registerCustomUpkeep", chainName)
    log(`🔗 LINK Token Address: ${linkTokenAddress}`, "registerCustomUpkeep", chainName)

    const registrar = hre.chainlink.automationRegistrar

    const { depositAmount, upkeepName, data, email, ocrConfig, source, upkeepContractAddress } = args
    log(`🔗 Using Upkeep Contract: ${upkeepContractAddress}`, "registerCustomUpkeep", chainName)

    const encryptedEmail = ethers.encodeBytes32String(email)
    const sender = deployer.address
    const adminAddress = deployer.address
    const checkData = ethers.toUtf8Bytes(data)

    log("🛠  Registering Upkeep via Hardhat Chainlink plugin...", "registerCustomUpkeep", chainName)

    try {
        const { transactionHash, upkeepId } = await registrar.registerUpkeep(
            keepersRegistrarAddress,
            linkTokenAddress,
            depositAmount,
            upkeepName,
            encryptedEmail,
            upkeepContractAddress,
            gasLimit,
            adminAddress,
            checkData,
            ocrConfig,
            source,
            sender,
        )

        log(
            `✅ Upkeep registered! Tx Hash: ${transactionHash}, Upkeep ID: ${upkeepId.toString()}`,
            "registerCustomUpkeep",
            chainName,
        )

        const automationForwarderAddress = await getAutomationForwarderById(keepersRegistrarAddress, upkeepId)

        const envFileName = `deployments.${type}` as EnvFileName

        log(`🔄 Updating automationForwarder in ${envFileName}...`, "registerCustomUpkeep", chainName)
        updateEnvVariable(`AUTOMATION_FORWARDER_${chainName}`, automationForwarderAddress, envFileName)

        log(`✅ automationForwarder updated in .env.${envFileName}!`, "registerCustomUpkeep", chainName)
    } catch (error) {
        err(`❌ Error registering upkeep: ${error.message}`, "registerCustomUpkeep", chainName)
        throw error
    }
}

async function getAutomationForwarderById(keepersRegistrarAddress: Address, upkeepId: BigNumber): Promise<Address> {
    console.log(`🔍 Fetching automationForwarder for Upkeep ID: ${upkeepId}...`)

    const AutomationRegistryInterfaceAbi = [
        "function getUpkeep(uint256 id) external view returns (tuple(uint96 balance, address lastKeeper, uint64 executeGas, uint96 amountSpent, address admin, uint64 maxValidBlocknumber, address target, uint32 numUpkeeps, address forwarder))",
    ]

    const [deployer] = await ethers.getSigners()

    const automationRegistryContract = await ethers.getContractAt(
        AutomationRegistryInterfaceAbi,
        keepersRegistrarAddress,
        deployer,
    )

    const upkeepDetails = await automationRegistryContract.getUpkeep(upkeepId)
    const automationForwarder = upkeepDetails.forwarder

    console.log(`✅ Found automationForwarder: ${automationForwarder}`)
    return automationForwarder
}
