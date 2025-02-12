import { task, types } from "hardhat/config"
import fs from "fs"
import path from "path"
import { getSimulationArgs } from "./simulationArgs"
import { simulateScript } from "@chainlink/functions-toolkit"
import { decodeCLFResponse } from "./decodeCLFResponse"
import log from "../../utils/log"
import { clfSecrets } from "../../constants/clfSecrets"
import { buildScript } from "./buildClfJs.task"

const CLFSimulationConfig = {
    maxOnChainResponseBytes: 1024,
    maxExecutionTimeMs: 100000,
    maxMemoryUsageMb: 128,
    numAllowedQueries: 20,
    maxQueryDurationMs: 10000,
    maxQueryUrlLength: 2048,
    maxQueryRequestBytes: 2048,
    maxQueryResponseBytes: 2097152,
}

/**
 * Simulates the execution of a script with the given arguments.
 * @param scriptPath - The path to the script file to simulate.
 * @param scriptName - The name of the script to simulate.
 * @param args - The array of arguments to pass to the simulation.
 */
async function simulateCLFScript(scriptPath: string, scriptName: string, args: string[]): Promise<string | undefined> {
    if (!fs.existsSync(scriptPath)) {
        console.error(`File not found: ${scriptPath}`)
        return
    }

    log(`Simulating ${scriptPath}`, "simulateCLFScript")
    try {
        const result = await simulateScript({
            source: 'const ethers = await import("npm:ethers@6.10.0"); return' + fs.readFileSync(scriptPath, "utf8"),
            bytesArgs: args,
            secrets: clfSecrets,
            ...CLFSimulationConfig,
        })

        const { errorString, capturedTerminalOutput, responseBytesHexstring } = result

        if (errorString) {
            log(errorString, "simulateCLFScript – Error:")
        }

        if (capturedTerminalOutput) {
            log(capturedTerminalOutput, "simulateCLFScript – Terminal output:")
        }

        if (responseBytesHexstring) {
            log(responseBytesHexstring, "simulateCLFScript – Response Bytes:")
            const decodedResponse = decodeCLFResponse(scriptName, responseBytesHexstring)
            if (decodedResponse) {
                log(decodedResponse, "simulateCLFScript – Decoded Response:")
            }
            return responseBytesHexstring
        }
    } catch (error) {
        console.error("Simulation failed:", error)
    }
}

task("clf-simulate", "Executes the JavaScript source code locally")
    .addParam("name", "Name of the function to simulate", "pool_get_total_balance", types.string)
    .addOptionalParam("concurrency", "Number of concurrent requests", 1, types.int)
    .setAction(async taskArgs => {
        const scriptName = taskArgs.name
        const basePath = path.join(__dirname, "../../", "./clf/dist")
        let scriptPath: string
        await buildScript(true, undefined, true)

        switch (scriptName) {
            case "pool_get_child_pools_liquidity":
                scriptPath = path.join(basePath, "./getChildPoolsLiquidity.min.js")
                break
            case "pool_collect_liq":
                scriptPath = path.join(basePath, "./withdrawalLiquidityCollection.min.js")
                break
            case "pool_redistribute_liq":
                scriptPath = path.join(basePath, "./redistributePoolsLiquidity.min.js")
                break
            default:
                console.error(`Unknown function: ${scriptName}`)
                return
        }

        const bytesArgs = await getSimulationArgs[scriptName]()
        const concurrency = taskArgs.concurrency
        const promises = Array.from({ length: concurrency }, () => simulateCLFScript(scriptPath, scriptName, bytesArgs))
        await Promise.all(promises)
    })

export default {}
