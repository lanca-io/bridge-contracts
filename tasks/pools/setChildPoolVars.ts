import { CNetworkNames } from "../../types/CNetwork"
import { setDstPools } from "./setDstPool"

export async function setChildPoolVars(poolChainName: CNetworkNames) {
    await setDstPools(poolChainName)
}
