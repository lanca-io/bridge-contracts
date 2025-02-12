import {
    collectLiquidityCodeUrl,
    ethersV6CodeUrl,
    getChildPoolsLiq,
    redistributeLiqJsCodeUrl,
} from "../constants/functionsJsCodeUrls"

export enum ClfJsCodeType {
    GetChildPoolsLiq,
    EthersV6,
    CollectLiq,
    RedistributeLiq,
}

async function fetchCode(url: string) {
    const response = await fetch(url)

    if (!response.ok) {
        throw new Error(`Failed to fetch code from ${url}: ${response.statusText}`)
    }
    return response.text()
}

export async function getClfJsCode(clfJsCodeType: ClfJsCodeType) {
    switch (clfJsCodeType) {
        case ClfJsCodeType.GetChildPoolsLiq:
            return fetchCode(getChildPoolsLiq)
        case ClfJsCodeType.EthersV6:
            return fetchCode(ethersV6CodeUrl)
        case ClfJsCodeType.CollectLiq:
            return fetchCode(collectLiquidityCodeUrl)
        case ClfJsCodeType.RedistributeLiq:
            return fetchCode(redistributeLiqJsCodeUrl)
        default:
            throw new Error(`Unknown ClfJsCodeType: ${clfJsCodeType}`)
    }
}
