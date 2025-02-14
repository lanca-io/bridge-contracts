import { SecretsManager } from "@chainlink/functions-toolkit"
import { getEthersSignerAndProvider } from "../../utils/getEthersSignerAndProvider"
import { conceroNetworks } from "../../constants"
import { err, log } from "../../utils/log"
import { task } from "hardhat/config"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { CNetwork } from "../../types/CNetwork"
import { mainnetChains } from "../../constants/liveChains"

export async function listClfSecrets(
    chain: CNetwork,
): Promise<{ [slotId: number]: { version: number; expiration: number } }> {
    const { signer } = getEthersSignerAndProvider(conceroNetworks[chain.name].url)
    const { functionsRouter, functionsDonIdAlias, functionsGatewayUrls } = chain
    if (!functionsGatewayUrls || functionsGatewayUrls.length === 0)
        throw Error(`No gatewayUrls found for ${chain.name}.`)

    const secretsManager = new SecretsManager({
        signer,
        functionsRouterAddress: functionsRouter,
        donId: functionsDonIdAlias,
    })
    await secretsManager.initialize()

    const { result } = await secretsManager.listDONHostedEncryptedSecrets(functionsGatewayUrls)
    const allSecrets = {}

    result.nodeResponses.forEach(nodeResponse => {
        if (nodeResponse.rows) {
            nodeResponse.rows.forEach(row => {
                if (allSecrets[row.slot_id] && allSecrets[row.slot_id].version !== row.version)
                    return err(
                        `Node mismatch for slot_id. ${allSecrets[row.slot_id]} !== ${row.slot_id}!`,
                        "listSecrets",
                        chain.name,
                    )
                allSecrets[row.slot_id] = { version: row.version, expiration: row.expiration }
            })
        }
    })
    log(`DON secrets for ${chain.name}:`, "listSecrets")
    console.log(allSecrets)
    return allSecrets
}

task("clf-list-secrets", "Displays encrypted secrets hosted on the DON")
    .addFlag("all", "List secrets from all chains")
    .setAction(async taskArgs => {
        const hre: HardhatRuntimeEnvironment = require("hardhat")
        const { all } = taskArgs

        if (all) {
            for (const chain of mainnetChains) {
                console.log(`\nListing secrets for ${chain.name}`)
                await listClfSecrets(chain)
            }
        } else {
            const name = hre.network.name as CNetwork
            await listClfSecrets(conceroNetworks[name])
        }
    })

export default {}
