;(async () => {
    try {
        const [_, __, ___, chainId, liquidityRequestedFromEachPool, withdrawalId] = bytesArgs

        const testnetChainsMap = {}
        const mainnetChainsMap = {}

        const BASE_CHAIN_ID = 8453
        const BASE_SEPOLIA_CHAIN_ID = 84532
        const numericChainId = parseInt(chainId, 16)
        let baseChainSelector, chainsMap

        if (numericChainId === BASE_SEPOLIA_CHAIN_ID) {
            baseChainSelector = '${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}'
            chainsMap = testnetChainsMap
        } else if (numericChainId === BASE_CHAIN_ID) {
            baseChainSelector = '${CL_CCIP_CHAIN_SELECTOR_BASE}'
            chainsMap = mainnetChainsMap
        } else {
            throw new Error('Unsupported chainId')
        }

        const getChainIdByUrl = url => {
            for (const chain in chainsMap) {
                if (chainsMap[chain].urls.includes(url)) return chainsMap[chain].chainId
            }
            return null
        }

        const baseChainSelector = `0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_BASE}').toString(16)}`
        // const baseChainSelector = `0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}').toString(16)}`;

        class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
            constructor(url) {
                super(url)
                this.url = url
            }
            async _send(payload) {
                if (payload.method === 'eth_estimateGas') {
                    return [{ jsonrpc: '2.0', id: payload.id, result: '0x1e8480' }]
                }
                if (payload.method === 'eth_chainId') {
                    const _chainId = getChainIdByUrl(this.url)
                    return [{ jsonrpc: '2.0', id: payload.id, result: _chainId }]
                }

                let resp = await fetch(this.url, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload),
                })
                const res = await resp.json()
                if (res.length === undefined) return [res]
                return res
            }
        }

        const poolAbi = ['function ccipSendToPool(uint64, uint256, bytes32) external']

        const promises = []

        for (const chainSelector in chainsMap) {
            const url = chainsMap[chainSelector].urls[Math.floor(Math.random() * chainsMap[chainSelector].urls.length)]
            const provider = new FunctionsJsonRpcProvider(url)
            const wallet = new ethers.Wallet('0x' + secrets.POOL_MESSENGER_0_PRIVATE_KEY, provider)
            const signer = wallet.connect(provider)
            const poolContract = new ethers.Contract(chainsMap[chainSelector].poolAddress, poolAbi, signer)
            promises.push(poolContract.ccipSendToPool(baseChainSelector, liquidityRequestedFromEachPool, withdrawalId))
        }

        await Promise.all(promises)

        return Functions.encodeUint256(1n)
    } catch (e) {
        const { message, code } = e
        if (
            code === 'NONCE_EXPIRED' ||
            message?.includes('replacement fee too low') ||
            message?.includes('already known')
        ) {
            return Functions.encodeUint256(1n)
        }
        throw e
    }
})()
