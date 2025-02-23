import "@nomicfoundation/hardhat-chai-matchers"
import { getFallbackClients } from "../../../utils/getViemClients"
import { getEnvVar } from "../../../utils"
import { approve } from "../../../utils/approve"
import { handleError } from "../../../utils/handleError"
import { Address, parseUnits, zeroAddress } from "viem"
import { conceroNetworks } from "../../../constants"
import { networkEnvKeys } from "../../../constants/conceroNetworks"

describe("bridge", async () => {
    it("should send and receive bridge", async () => {
        try {
            const srcChain = conceroNetworks.arbitrumSepolia
            const dstChain = conceroNetworks.baseSepolia
            const bridgeAmount = parseUnits("4", 6)
            const srcLancaOrchestrator = getEnvVar(
                `LANCA_ORCHESTRATOR_PROXY_${networkEnvKeys[srcChain.name]}`,
            ) as Address
            const srcChainUsdc = getEnvVar(`USDC_${networkEnvKeys[srcChain.name]}`) as Address
            const { publicClient: srcChainPublicClient, walletClient: srcChainWalletClient } =
                getFallbackClients(srcChain)
            const { abi: lancaOrchestratorAbi } = await import(
                "../../../artifacts/contracts/orchestrator/LancaOrchestrator.sol/LancaOrchestrator.json"
            )
            const { abi: lancaBridgeAbi } = await import(
                "../../../artifacts/contracts/bridge/LancaBridge.sol/LancaBridge.json"
            )

            await approve(srcChainUsdc, srcLancaOrchestrator, bridgeAmount, srcChainWalletClient, srcChainPublicClient)

            const bridgeStruct = {
                token: srcChainUsdc,
                receiver: srcChainWalletClient.account?.address,
                amount: bridgeAmount,
                dstChainSelector: dstChain.chainSelector,
                compressedDstSwapData: "0x",
            }

            const integrationStruct = {
                integrator: zeroAddress,
                feeBps: 0n,
            }

            const sendBridgeReq = (
                await srcChainPublicClient.simulateContract({
                    account: srcChainWalletClient.account,
                    address: srcLancaOrchestrator,
                    abi: [...lancaOrchestratorAbi, ...lancaBridgeAbi],
                    functionName: "bridge",
                    args: [bridgeStruct, integrationStruct],
                })
            ).request
            const sendBridgeHash = await srcChainWalletClient.writeContract(sendBridgeReq)

            const sendBridgeStatus = (await srcChainPublicClient.waitForTransactionReceipt({ hash: sendBridgeHash }))
                .status

            if (sendBridgeStatus === "success") {
                console.log(`bridge successful`, "sendBridge", "hash:", sendBridgeHash)
            } else {
                throw new Error(`bridge failed. Hash: ${sendBridgeHash}`)
            }
        } catch (error) {
            handleError(error, "bridge test")
            throw new Error("failed")
        }
    }).timeout(0)
})
