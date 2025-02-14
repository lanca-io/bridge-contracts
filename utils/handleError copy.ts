import { ContractFunctionExecutionError } from "viem"
import { err } from "./log"

export function handleError(error: any, place: string) {
    if (error instanceof ContractFunctionExecutionError) {
        err(`Short message: ${error.shortMessage} \n Meta messages: ${error.metaMessages}`, place)
    } else {
        throw error
    }
}
