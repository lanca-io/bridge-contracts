(async () => {
    try {
        const [, , , chainId, liquidityRequestedFromEachPool, withdrawalId] = bytesArgs;
        const testnetChainsMap = {
            ['10344971235874465080']: {
                urls: [`https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`],
                chainId: '0x14a34',
                usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
                poolAddress: '0x367fd6BE1B78767c15b82a181e98158f426551c0',
            },
            ['3478487238524512106']: {
                urls: [`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`],
                chainId: '0x66eee',
                usdcAddress: '0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d',
                poolAddress: '0xa246a2cFfC46B754771C1FC90d0C06595754a324',
            },
            ['14767482510784806043']: {
                urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`],
                chainId: '0xa869',
                usdcAddress: '0x5425890298aed601595a70AB815c96711a31Bc65',
                poolAddress: '0x7A6F837CC8d4156812700F1C199B9d5931005FcC',
            },
        };
        const mainnetChainsMap = {
            ['4949039107694359620']: {
                urls: [`https://arbitrum-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`],
                chainId: '0xa4b1',
                usdcAddress: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
                poolAddress: '0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d',
            },
            ['4051577828743386545']: {
                urls: [`https://polygon-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`],
                chainId: '0x89',
                usdcAddress: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
                poolAddress: '0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d',
            },
            ['6433500567565415381']: {
                urls: [`https://avalanche-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`],
                chainId: '0xa86a',
                usdcAddress: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E',
                poolAddress: '0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d',
            },
            ['15971525489660198786']: {
                urls: [`https://base-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`],
                chainId: '0x2105',
                usdcAddress: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
                poolAddress: '0x0AE1B2730066AD46481ab0a5fd2B5893f8aBa323',
            },
            ['3734403246176062136']: {
                urls: [`https://optimism-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`],
                chainId: '0xa',
                usdcAddress: '0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85',
                poolAddress: '0x8698c6DF1E354Ce3ED0dE508EF7AF4baB85D2F2D',
            },
        };
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
            if (chainSelector === baseChainSelector) continue;
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
