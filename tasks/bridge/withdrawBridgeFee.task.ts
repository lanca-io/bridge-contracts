import { conceroNetworks } from "../../constants"
import { formatUnits } from "viem"
import { getEnvVar } from "../../utils/"
import { getFallbackClients } from "../../utils/getViemClients"
import { networkEnvKeys } from "../../constants/conceroNetworks"
import readline from "readline"
import { task } from "hardhat/config"

export enum ProxyEnum {
    lancaBridgeProxy = "LANCA_BRIDGE_PROXY",
}

export type TokenInfo = {
    chain: string
    symbol: string
    address: string
    decimals: number
    balance: string
    withdrawableBalance: string
    pendingSettlement: string
}

export type ChainBalanceSummary = {
    Chain: string
    Symbol: string
    TokenAddress: string
    Balance: string
    Withdrawable: string
    PendingSettlement: string
}

/**
 * Monitors USDC balances in LancaBridge contracts across networks
 * @param isTestnet Whether to check testnet or mainnet networks
 * @returns Record of TokenInfo arrays indexed by chain name
 */
export async function monitorLancaBridgeBalances(isTestnet: boolean): Promise<Record<string, TokenInfo[]>> {
    const networkType = isTestnet ? "testnet" : "mainnet"
    const balancesByChain: Record<string, TokenInfo[]> = {}

    // Filter networks based on testnet/mainnet
    const networks = Object.entries(conceroNetworks).filter(
        ([_, config]) => config.type === networkType && config.viemChain,
    )

    console.log(`Checking LancaBridge USDC balances on ${networkType} networks...`)

    for (const [chainName, chain] of networks) {
        try {
            // Get contract address
            const bridgeAddress = getEnvVar(`LANCA_BRIDGE_PROXY_${networkEnvKeys[chainName]}`)
            if (!bridgeAddress) continue

            // Get USDC address
            const usdcAddress = process.env[`USDC_${networkEnvKeys[chainName]}`]
            if (!usdcAddress) continue

            const { publicClient } = getFallbackClients(chain)
            const { abi } = await import("../../artifacts/contracts/bridge/LancaBridge.sol/LancaBridge.json")

            // Get USDC balance
            const balance = await publicClient.readContract({
                address: usdcAddress as `0x${string}`,
                abi: [
                    {
                        inputs: [{ type: "address", name: "account" }],
                        name: "balanceOf",
                        outputs: [{ type: "uint256", name: "" }],
                        type: "function",
                        stateMutability: "view",
                    },
                ],
                functionName: "balanceOf",
                args: [bridgeAddress as `0x${string}`],
            })

            const decimals = 6n
            // Calculate pending settlement amount
            let pendingSettlement = BigInt(0)

            // Collect chain selectors from conceroNetworks based on network type
            const possibleDstChains: bigint[] = []
            Object.values(conceroNetworks).forEach(network => {
                if (network.type === networkType && network.chainSelector) {
                    possibleDstChains.push(BigInt(network.chainSelector))
                }
            })

            for (const dstChainSelector of possibleDstChains) {
                try {
                    const dstPendingAmount = await publicClient.readContract({
                        address: bridgeAddress as `0x${string}`,
                        abi,
                        functionName: "getPendingSettlementTxAmountByDstChain",
                        args: [dstChainSelector],
                    })

                    pendingSettlement += BigInt(dstPendingAmount.toString())
                } catch (error) {
                    console.log(
                        `Error getting pending settlement for chain ${dstChainSelector} on ${chainName}: ${error}`,
                    )
                }
            }

            const withdrawableBalance = balance - pendingSettlement

            balancesByChain[chainName] = [
                {
                    chain: chainName,
                    symbol: "USDC",
                    address: usdcAddress,
                    decimals: Number(decimals),
                    balance: balance.toString(),
                    withdrawableBalance: withdrawableBalance.toString(),
                    pendingSettlement: pendingSettlement.toString(),
                },
            ]
        } catch (error) {
            console.error(`Error checking USDC balance on ${chainName}:`, error)
        }
    }

    return balancesByChain
}

/**
 * Formats raw balance data for display with totals
 * @param balancesByChain Raw balance data by chain
 * @returns Formatted balance summaries by chain with totals
 */
export function formatBalancesForDisplay(
    balancesByChain: Record<string, TokenInfo[]>,
): Record<string, ChainBalanceSummary[]> {
    const displayInfoByChain: Record<string, ChainBalanceSummary[]> = {}
    let totalWithdrawable = BigInt(0)
    let totalBalance = BigInt(0)
    let totalPending = BigInt(0)
    let decimals = 6 // Default USDC decimals

    for (const chainName in balancesByChain) {
        const chainBalances = balancesByChain[chainName]

        const displayedTokenInfos = chainBalances.map(token => {
            const balanceBigInt = BigInt(token.balance)
            const withdrawableBigInt = BigInt(token.withdrawableBalance)
            const pendingBigInt = BigInt(token.pendingSettlement)

            // Use the token's decimals for consistent calculations
            decimals = token.decimals

            // Accumulate totals
            totalBalance += balanceBigInt
            totalWithdrawable += withdrawableBigInt
            totalPending += pendingBigInt

            return {
                Chain: chainName,
                Symbol: token.symbol,
                TokenAddress: token.address,
                Balance: `${formatUnits(balanceBigInt, token.decimals)} USDC`,
                Withdrawable: `${formatUnits(withdrawableBigInt, token.decimals)} USDC`,
                PendingSettlement: `${formatUnits(pendingBigInt, token.decimals)} USDC`,
            }
        })

        displayInfoByChain[chainName] = displayedTokenInfos
    }

    // Add totals summary
    displayInfoByChain["TOTALS"] = [
        {
            Chain: "ALL CHAINS",
            Symbol: "USDC",
            TokenAddress: "---",
            Balance: `${formatUnits(totalBalance, decimals)} USDC`,
            Withdrawable: `${formatUnits(totalWithdrawable, decimals)} USDC`,
            PendingSettlement: `${formatUnits(totalPending, decimals)} USDC`,
        },
    ]

    return displayInfoByChain
}

/**
 * Displays the current balances and asks for confirmation
 * @param balancesByChain Formatted balance data
 * @returns Promise resolving to whether user confirmed withdrawal
 */
async function promptForWithdrawal(formattedBalances: Record<string, ChainBalanceSummary[]>): Promise<boolean> {
    // Display the balances
    console.log("\nCurrent USDC balances:")
    for (const chainName in formattedBalances) {
        console.log(`\n${chainName}:`)
        console.table(formattedBalances[chainName])
    }

    // Create readline interface for user confirmation
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
    })

    // Ask for user confirmation
    const answer = await new Promise<string>(resolve => {
        rl.question("\nDo you want to withdraw the available USDC fees? (Y/N): ", resolve)
    })

    rl.close()
    return answer.toLowerCase() === "y" || answer.toLowerCase() === "yes"
}

/**
 * Executes withdrawal of USDC from LancaBridge contracts
 * @param isTestnet Whether to perform withdrawal on testnet or mainnet
 * @param balancesByChain Raw balance data by chain
 */
async function executeWithdrawals(isTestnet: boolean, balancesByChain: Record<string, TokenInfo[]>): Promise<void> {
    const networkType = isTestnet ? "testnet" : "mainnet"
    const networks = Object.entries(conceroNetworks).filter(
        ([_, config]) => config.type === networkType && config.viemChain,
    )

    console.log("\nProcessing withdrawals...")

    for (const [chainName, chain] of networks) {
        // Skip chains with no balances
        if (!balancesByChain[chainName] || balancesByChain[chainName].length === 0) continue

        const tokenInfo = balancesByChain[chainName][0]
        const withdrawableBalance = BigInt(tokenInfo.withdrawableBalance)

        // Skip if no withdrawable balance
        if (withdrawableBalance <= BigInt(0)) {
            console.log(`No withdrawable balance on ${chainName}, skipping.`)
            continue
        }

        try {
            // Get contract address
            const bridgeAddress = getEnvVar(`LANCA_BRIDGE_PROXY_${networkEnvKeys[chainName]}`)
            if (!bridgeAddress) continue

            // Get wallet client for transaction
            const { walletClient } = getFallbackClients(chain)
            const { abi } = await import("../../artifacts/contracts/bridge/LancaBridge.sol/LancaBridge.json")

            console.log(`Withdrawing ${formatUnits(withdrawableBalance, tokenInfo.decimals)} USDC from ${chainName}...`)

            // Execute withdraw fee transaction
            const hash = await walletClient.writeContract({
                address: bridgeAddress,
                abi,
                functionName: "withdrawFee",
                args: [],
            })

            console.log(`Transaction submitted on ${chainName}: ${hash}`)
            console.log(`Withdrawn: ${formatUnits(withdrawableBalance, tokenInfo.decimals)} USDC`)

            // Wait for transaction confirmation
            const { publicClient } = getFallbackClients(chain)
            const receipt = await publicClient.waitForTransactionReceipt({ hash })
            console.log(`Transaction ${receipt.status === "success" ? "succeeded" : "failed"} on ${chainName}`)
        } catch (error) {
            console.error(`Error withdrawing from ${chainName}:`, error)
        }
    }

    console.log("\nWithdrawal process completed.")
}

/**
 * Main function that orchestrates the withdrawal flow
 * @param isTestnet Whether to operate on testnet or mainnet
 */
export async function withdrawFee(isTestnet: boolean): Promise<void> {
    // 1. Get and display current balances
    const balancesByChain = await monitorLancaBridgeBalances(isTestnet)
    const formattedBalances = formatBalancesForDisplay(balancesByChain)

    // 2. Prompt for confirmation
    const shouldProceed = await promptForWithdrawal(formattedBalances)

    if (!shouldProceed) {
        console.log("Withdrawal cancelled.")
        return
    }

    // 3. Execute withdrawals
    await executeWithdrawals(isTestnet, balancesByChain)
}

task("withdraw-bridge-fee", "Withdraw fee from the bridge")
    .addFlag("testnet", "Whether to operate on testnet or mainnet")
    .setAction(async ({ testnet }) => {
        await withdrawFee(testnet)
    })

export default {}
