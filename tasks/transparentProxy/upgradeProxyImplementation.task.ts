import { getEnvAddress } from "../../utils";
import conceroNetworks from "../../constants/conceroNetworks";
import { privateKeyToAccount } from "viem/accounts";
import log from "../../utils/log";
import { task } from "hardhat/config";
import { envPrefixes, ProxyEnum, viemReceiptConfig, writeContractConfig } from "../../constants/deploymentVariables";
import { formatGas } from "../../utils/formatting";
import { EnvPrefixes } from "../../types/deploymentVariables";
import { getFallbackClients } from "../../utils/getViemClients";
import { CNetworkNames } from "../../types/CNetwork";

export async function upgradeProxyImplementation(hre, shouldPause: boolean) {
    const chainName = hre.network.name as CNetworkNames;
    const { viemChain } = conceroNetworks[chainName];

    let implementationKey: keyof EnvPrefixes;

    if (shouldPause) {
        implementationKey = envPrefixes.pause;
    } else {
        implementationKey = ProxyEnum.conceroRouterProxy;
    }

    const proxyType = ProxyEnum.conceroRouterProxy;

    const { abi: proxyAdminAbi } = await import(
        "../../artifacts/contracts/proxy/TransparentProxyAdmin.sol/TransparentProxyAdmin.json"
    );

    const viemAccount = privateKeyToAccount(`0x${process.env.PROXY_DEPLOYER_PRIVATE_KEY}`);
    const { walletClient, publicClient } = getFallbackClients(conceroNetworks[chainName], viemAccount);

    const [conceroProxy, conceroProxyAlias] = getEnvAddress(proxyType, chainName);
    const [proxyAdmin, proxyAdminAlias] = getEnvAddress(`${proxyType}Admin`, chainName);
    const [newImplementation, newImplementationAlias] = getEnvAddress(implementationKey, chainName);
    const [pauseDummy, pauseAlias] = getEnvAddress("pause", chainName);

    const implementation = shouldPause ? pauseDummy : newImplementation;
    const implementationAlias = shouldPause ? pauseAlias : newImplementationAlias;

    const txHash = await walletClient.writeContract({
        address: proxyAdmin,
        abi: proxyAdminAbi,
        functionName: "upgradeAndCall",
        account: viemAccount,
        args: [conceroProxy, implementation, "0x"],
        chain: viemChain,
        ...writeContractConfig,
    });

    const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ ...viemReceiptConfig, hash: txHash });

    log(
        `Upgraded via ${proxyAdminAlias}: ${conceroProxyAlias}.implementation -> ${implementationAlias}. Gas : ${formatGas(cumulativeGasUsed)}, hash: ${txHash}`,
        `setProxyImplementation : ${proxyType}`,
        chainName,
    );
}

task("upgrade-proxy-implementation", "Upgrades the proxy implementation")
    .addFlag("pause", "Pause the proxy before upgrading", false)
    .addParam("proxytype", "The type of the proxy to upgrade", undefined)
    .setAction(async taskArgs => {
        await upgradeProxyImplementation(hre, taskArgs.proxytype, taskArgs.pause);
    });

export default {};
