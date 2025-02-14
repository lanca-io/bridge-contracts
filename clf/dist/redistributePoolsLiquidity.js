(async () => {
    try {
        const [_, __, ___, newPoolChainSelector, distributeLiquidityRequestId, distributionType, chainId] = bytesArgs;
        const chainsMapTestnet = {
            ['10344971235874465080']: {
                urls: ['https://base-sepolia-rpc.publicnode.com'],
                chainId: '0x14a34',
                usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
                poolAddress: '0x3f89F49e33d437018dfea711DA7e38c1Fa4d126D',
            },
        };
        const chainsMapMainnet = {};
        let chainsMap;
        const chainIdNumber = parseInt(chainId, 16);
        if (chainIdNumber === 84532) {
            chainsMap = chainsMapTestnet;
        } else if (chainIdNumber === 8453) {
            chainsMap = chainsMapMainnet;
        } else {
            throw new Error(`Wrong chain id ${chainIdNumber}`);
        }
        const erc20Abi = ['function balanceOf(address) external view returns (uint256)'];
        const poolAbi = [
            'function s_loansInUse() external view returns (uint256)',
            'function distributeLiquidity(uint64, uint256, bytes32) external',
            'function liquidatePool(bytes32) external',
        ];
        const chainSelectorsArr = Object.keys(chainsMap);
        class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
            constructor(url) {
                super(url);
                this.url = url;
            }
            async _send(payload) {
                if (payload.method === 'eth_estimateGas') {
                    return [{ jsonrpc: '2.0', id: payload.id, result: '0x1e8480' }];
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
        const getProviderByChainSelector = _chainSelector => {
            const url =
                chainsMap[_chainSelector].urls[Math.floor(Math.random() * chainsMap[_chainSelector].urls.length)];
            return new FunctionsJsonRpcProvider(url);
        };
        const getSignerByChainSelector = _chainSelector => {
            const provider = getProviderByChainSelector(_chainSelector);
            const wallet = new ethers.Wallet('0x' + secrets.POOL_MESSENGER_0_PRIVATE_KEY, provider);
            return wallet.connect(provider);
        };
        if (distributionType === '0x00') {
            const getPoolsBalances = async () => {
                const getBalancePromises = [];
                for (const chain in chainsMap) {
                    if (BigInt(chain) === BigInt(newPoolChainSelector)) continue;
                    const provider = getProviderByChainSelector(chain);
                    const erc20 = new ethers.Contract(chainsMap[chain].usdcAddress, erc20Abi, provider);
                    const pool = new ethers.Contract(chainsMap[chain].poolAddress, poolAbi, provider);
                    getBalancePromises.push(erc20.balanceOf(chainsMap[chain].poolAddress));
                    getBalancePromises.push(pool.s_loansInUse());
                }
                const results = await Promise.all(getBalancePromises);
                const balances = {};
                for (let i = 0, k = 0; i < results.length; i += 2, k++) {
                    balances[chainSelectorsArr[k]] = BigInt(results[i]) + BigInt(results[i + 1]);
                }
                return balances;
            };
            const poolsBalances = await getPoolsBalances();
            const poolsTotalBalance = chainSelectorsArr.reduce((acc, pool) => {
                if (BigInt(pool) === BigInt(newPoolChainSelector)) return acc;
                return acc + BigInt(poolsBalances[pool]);
            }, 0n);
            const newPoolsCount = BigInt(Object.keys(chainsMap).length + 1);
            const newPoolBalance = poolsTotalBalance / newPoolsCount;
            const distributeAmountPromises = [];
            for (const chain in chainsMap) {
                if (BigInt(chain) === BigInt(newPoolChainSelector)) continue;
                const signer = getSignerByChainSelector(chain);
                const poolContract = new ethers.Contract(chainsMap[chain].poolAddress, poolAbi, signer);
                const amountToDistribute = poolsBalances[chain] - newPoolBalance;
                distributeAmountPromises.push(
                    poolContract.distributeLiquidity(
                        newPoolChainSelector,
                        amountToDistribute,
                        distributeLiquidityRequestId,
                    ),
                );
            }
            await Promise.all(distributeAmountPromises);
            return Functions.encodeUint256(1n);
        } else if (distributionType === '0x01') {
        }
        throw new Error('Invalid distribution type');
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
