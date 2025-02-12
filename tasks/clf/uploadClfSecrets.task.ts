import { task, types } from "hardhat/config"
import { SecretsManager } from "@chainlink/functions-toolkit"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { CNetwork, CNetworkNames } from "../../types/CNetwork"
import { getEthersSignerAndProvider } from "../../utils/getEthersSignerAndProvider"
import { CLF_SECRETS_MAINNET_EXPIRATION, CLF_SECRETS_TESTNET_EXPIRATION, clfSecrets } from "../../constants/clfSecrets"
import { err, log } from "../../utils/log"
import { listClfSecrets } from "./listClfSecrets.task"
import updateEnvVariable from "../../utils/updateEnvVariable"
import { conceroNetworks } from "../../constants"
import { mainnetChains } from "../../constants/liveChains"
import { networkEnvKeys } from "../../constants/conceroNetworks"

export async function uploadClfSecrets(chains: CNetwork[], slotid: string) {
    const slotId = parseInt(slotid)

    for (const chain of chains) {
        const minutesUntilExpiration =
            chains[0].type === "testnet" ? CLF_SECRETS_TESTNET_EXPIRATION : CLF_SECRETS_MAINNET_EXPIRATION
        const { functionsRouter, functionsDonIdAlias, functionsGatewayUrls, name } = chain
        const { signer } = getEthersSignerAndProvider(chain.url)

        const secretsManager = new SecretsManager({
            signer,
            functionsRouterAddress: functionsRouter,
            donId: functionsDonIdAlias,
        })
        await secretsManager.initialize()

        if (!clfSecrets) {
            err("No secrets to upload.", "donSecrets/upload", name)
            return
        }

        log("Uploading secrets to DON", "donSecrets/upload", name)
        const encryptedSecretsObj = await secretsManager.encryptSecrets(clfSecrets)

        if (!functionsGatewayUrls || functionsGatewayUrls.length === 0) {
            throw Error(`No gatewayUrls found for ${name}.`)
        }

        const { version } = await secretsManager.uploadEncryptedSecretsToDON({
            encryptedSecretsHexstring: encryptedSecretsObj.encryptedSecrets,
            gatewayUrls: functionsGatewayUrls,
            slotId,
            minutesUntilExpiration,
        })

        log(
            `DONSecrets uploaded. slot_id: ${slotId}, version: ${version}, ttl: ${minutesUntilExpiration}`,
            "donSecrets/upload",
            name,
        )

        await listClfSecrets(chain)

        updateEnvVariable(`CLF_DON_SECRETS_VERSION_${networkEnvKeys[name]}`, version, `clf`)
    }
}

task("clf-secrets-upload", "Encrypts and uploads secrets to the DON")
    .addParam(
        "slotid",
        "Storage slot number 0 or higher - if the slotid is already in use, the existing secrets for that slotid will be overwritten",
    )
    .addOptionalParam("ttl", "Time to live - minutes until the secrets hosted on the DON expire", 4320, types.int)
    .addFlag("all", "Upload secrets to all networks")
    .addFlag("updatecontracts", "Update the contracts with the new secrets")
    .setAction(async taskArgs => {
        const hre: HardhatRuntimeEnvironment = require("hardhat")
        const { slotid, ttl, all } = taskArgs

        const processNetwork = async (chain: CNetwork) => {
            await uploadClfSecrets([chain], slotid, ttl)
        }

        if (all) {
            for (const liveChain of mainnetChains) {
                await processNetwork(liveChain)
            }
        } else {
            await processNetwork(conceroNetworks[hre.network.name as CNetworkNames])
        }
    })

export default {}
