import "@nomicfoundation/hardhat-chai-matchers"
import { conceroNetworks, networkEnvKeys } from "../../../constants"
import { getFallbackClients } from "../../../utils/getViemClients"
import { getEnvVar } from "../../../utils"
import { approve } from "../../../utils/approve"
import { handleError } from "../../../utils/handleError"
import { Address, parseUnits } from "viem"

describe("sendMessage\n", async () => {
    it("should send and receiveMessage in test concero client", async () => {
        try {
            const srcChain = conceroNetworks.baseSepolia
            const dstChain = conceroNetworks.avalancheFuji
            const srcLancaBridge = getEnvVar(`LANCA_BRIDGE_PROXY${networkEnvKeys[srcChain.name]}`) as Address
            const srcChainUsdc = getEnvVar(`USDC_${networkEnvKeys[srcChain.name]}`) as Address
            const { publicClient: srcChainPublicClient, walletClient: srcChainWalletClient } =
                getFallbackClients(srcChain)
            const { abi: lancaBridgeAbi } = await import(
                "../../../artifacts/contracts/bridge/LancaBridge.sol/LancaBridge.json"
            )
            const bridgeAmount = parseUnits("2", 6)

            await approve(srcChainUsdc, srcLancaBridge, bridgeAmount, srcChainWalletClient, srcChainPublicClient)

            const bridgeStruct = {
                amount: srcChainUsdc,
            }

            const sendMessageReq = (
                await srcChainPublicClient.simulateContract({
                    account: srcChainWalletClient.account,
                    address: srcLancaBridge,
                    abi: conceroRouterAbi,
                    functionName: "sendMessage",
                    args: [message],
                })
            ).request
            const sendMessageHash = await srcChainWalletClient.writeContract(sendMessageReq)
            const sendMessageStatus = await srcChainPublicClient.waitForTransactionReceipt({ hash: sendMessageHash })

            if (sendMessageStatus.status === "success") {
                console.log(`sendMessage successful`, "sendMessage", "hash:", sendMessageHash)
            } else {
                throw new Error(`sendMessage failed. Hash: ${sendMessageHash}`)
            }
        } catch (error) {
            handleError(error, "send message test")
        }
    }).timeout(0)
})
