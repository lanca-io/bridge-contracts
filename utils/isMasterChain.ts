import { CNetwork } from "../types/CNetwork"

export const isMasterChain = (conceroChain: CNetwork) =>
    conceroChain.name === "base" || conceroChain.name === "baseSepolia"
