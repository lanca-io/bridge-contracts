(async () => {
    try {
        const [, , , chainId, liquidityRequestedFromEachPool, withdrawalId] = bytesArgs;
        const testnetChainsMap = {
            ['10344971235874465080']: {
                urls: [`https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`],
                chainId: '0x14a34',
                usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
                poolAddress: '0x3f89F49e33d437018dfea711DA7e38c1Fa4d126D',
            },
            ['3478487238524512106']: {
                urls: [`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`],
                chainId: '0x66eee',
                usdcAddress: '0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d',
                poolAddress: '0x1416f873EFa0fb98b1331Df2Fd2F5d66B33AAB9F',
            },
            ['14767482510784806043']: {
                urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`],
                chainId: '0xa869',
                usdcAddress: '0x5425890298aed601595a70AB815c96711a31Bc65',
                poolAddress: '0x788b8B75d486da5C0bd8bBc366e585C5a664f5Cf',
            },
        };
        const mainnetChainsMap = {};
        const BASE_CHAIN_ID = 8453;
        const BASE_SEPOLIA_CHAIN_ID = 84532;
        const numericChainId = parseInt(chainId, 16);
        let baseChainSelector, chainsMap;
        if (numericChainId === BASE_SEPOLIA_CHAIN_ID) {
            baseChainSelector = '10344971235874465080';
            chainsMap = testnetChainsMap;
        } else if (numericChainId === BASE_CHAIN_ID) {
            baseChainSelector = '15971525489660198786';
            chainsMap = mainnetChainsMap;
        } else {
            throw new Error('Unsupported chainId');
        }
        const getChainIdByUrl = url => {
            for (const chain in chainsMap) {
                if (chainsMap[chain].urls.includes(url)) return chainsMap[chain].chainId;
            }
            return null;
        };
        class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
            constructor(url) {
                super(url);
                this.url = url;
            }
            async _send(payload) {
                if (payload.method === 'eth_estimateGas') {
                    return [{ jsonrpc: '2.0', id: payload.id, result: '0x1e8480' }];
                }
                if (payload.method === 'eth_chainId') {
                    const _chainId = getChainIdByUrl(this.url);
                    return [{ jsonrpc: '2.0', id: payload.id, result: _chainId }];
                }
                let resp = await fetch(this.url, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload),
                });
                const res = await resp.json();
                if (res.length === undefined) return [res];
                return res;
            }
        }
        const poolAbi = ['function ccipSendToPool(uint64, uint256, bytes32) external'];
        const promises = [];
        for (const chainSelector in chainsMap) {
            const url = chainsMap[chainSelector].urls[Math.floor(Math.random() * chainsMap[chainSelector].urls.length)];
            const provider = new FunctionsJsonRpcProvider(url);
            const wallet = new ethers.Wallet('0x' + secrets.POOL_MESSENGER_0_PRIVATE_KEY, provider);
            const signer = wallet.connect(provider);
            const poolContract = new ethers.Contract(chainsMap[chainSelector].poolAddress, poolAbi, signer);
            promises.push(poolContract.ccipSendToPool(baseChainSelector, liquidityRequestedFromEachPool, withdrawalId));
        }
        await Promise.all(promises);
        return Functions.encodeUint256(1n);
    } catch (e) {
        const { message, code } = e;
        if (
            code === 'NONCE_EXPIRED' ||
            message?.includes('replacement fee too low') ||
            message?.includes('already known')
        ) {
            return Functions.encodeUint256(1n);
        }
        throw e;
    }
})();
